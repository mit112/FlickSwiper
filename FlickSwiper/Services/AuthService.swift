import Foundation
import AuthenticationServices
import CryptoKit
import UIKit
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseCore
@preconcurrency import FirebaseFirestore
import GoogleSignIn
import os

/// Manages authentication via Firebase Auth (Sign in with Apple + Google Sign-In)
/// and user profile operations in Firestore.
///
/// Usage: Inject as an environment object at app root.
/// Views observe `currentUser` and `isSignedIn` for conditional UI.
@Observable
@MainActor
final class AuthService: NSObject {
    
    // MARK: - Published State
    
    /// The currently signed-in Firebase user, or nil if signed out.
    private(set) var currentUser: FirebaseAuth.User?
    
    /// Convenience check for UI bindings.
    var isSignedIn: Bool { currentUser != nil }
    
    /// The display name from the Firestore `users` document (not Firebase Auth profile).
    /// This is the source of truth for display name shown in the app.
    private(set) var displayName: String = ""
    
    /// Error message for UI display. Set briefly, then cleared.
    var errorMessage: String?
    
    /// True while an auth operation is in progress.
    private(set) var isLoading: Bool = false
    
    // MARK: - Private
    
    /// Computed property — `Firestore.firestore()` returns a singleton so this is cheap.
    /// Avoids initialization before `FirebaseApp.configure()` is called.
    private var db: Firestore { Firestore.firestore() }
    private let nameValidator = DisplayNameValidator()
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "Auth")
    
    /// Unhashed nonce for the current Sign in with Apple request.
    /// Kept in memory to verify the identity token response.
    private var currentNonce: String?
    
    /// Auth state listener handle for cleanup.
    /// No deinit cleanup needed — AuthService lives for the entire app lifecycle
    /// as a @State on FlickSwiperApp, so it's never deallocated while running.
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    /// Continuation for bridging the ASAuthorizationController delegate callback
    /// into Swift concurrency.
    private var signInContinuation: CheckedContinuation<ASAuthorization, Error>?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Don't call setupAuthStateListener() here — Auth.auth() will crash
        // if FirebaseApp.configure() hasn't been called yet. @State properties
        // on App structs initialize before init() runs.
    }
    
    /// Must be called after FirebaseApp.configure(). Sets up the auth state listener.
    func configure() {
        guard authStateListener == nil else { return } // Already configured
        setupAuthStateListener()
    }
    

    
    // MARK: - Auth State Observation
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.currentUser = user
                if let user {
                    await self.loadDisplayName(for: user.uid)
                } else {
                    self.displayName = ""
                }
            }
        }
    }
    
    // MARK: - Sign In with Apple
    
    /// Initiates the full Sign in with Apple → Firebase Auth flow.
    /// Call this from a button tap. Throws on cancellation or failure.
    func signInWithApple() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // 1. Generate cryptographic nonce
        let nonce = randomNonceString()
        currentNonce = nonce
        
        // 2. Build Apple auth request
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        // 3. Present Apple sign-in sheet and await result
        let authorization = try await performAppleAuthorization(request: request)
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredential
        }
        
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.missingIdentityToken
        }
        
        // 4. Create Firebase credential with Apple token + nonce + full name
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        // 5. Sign in to Firebase (with collision detection)
        let authResult: AuthDataResult
        do {
            authResult = try await Auth.auth().signIn(with: credential)
        } catch let error as NSError where error.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue {
            throw AuthError.accountExistsWithDifferentProvider
        }
        let user = authResult.user
        logger.info("Signed in with Apple. UID: \(user.uid)")
        
        // 6. Create or update Firestore user document
        //    Apple only provides the name on FIRST authorization. Capture it now.
        let name = nameValidator.displayName(from: appleIDCredential.fullName)
        try await createOrUpdateUserDoc(uid: user.uid, displayName: name)
        
        // 7. Update Firebase Auth profile display name (for consistency)
        if user.displayName == nil || user.displayName?.isEmpty == true {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
        }
    }
    
    /// Bridges ASAuthorizationController (delegate-based) into async/await.
    private func performAppleAuthorization(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }
    
    // MARK: - Sign In with Google
    
    /// Initiates the full Google Sign-In → Firebase Auth flow.
    /// Call this from a button tap. Throws on cancellation or failure.
    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // 1. Get the client ID from the Firebase configuration
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingGoogleClientID
        }
        
        // 2. Get the topmost view controller for presenting the Google sign-in UI.
        //    Must traverse the presentedViewController chain because this is often
        //    called from a SwiftUI .sheet (SignInPromptView), so rootViewController
        //    alone won't be the topmost.
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noRootViewController
        }
        var presentingVC = rootViewController
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }
        
        // 3. Configure and perform Google Sign-In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
        } catch let error as NSError {
            // GIDSignInError.canceled = -5
            if error.domain == "com.google.GIDSignIn" && error.code == -5 {
                throw AuthError.cancelled
            }
            throw error
        }
        
        // 4. Get the ID token from the result
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingIdentityToken
        }
        
        // 5. Create Firebase credential with Google tokens
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        
        // 6. Sign in to Firebase (with collision detection)
        let authResult: AuthDataResult
        do {
            authResult = try await Auth.auth().signIn(with: credential)
        } catch let error as NSError where error.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue {
            throw AuthError.accountExistsWithDifferentProvider
        }
        let user = authResult.user
        logger.info("Signed in with Google. UID: \(user.uid)")
        
        // 7. Create or update Firestore user document
        //    Google provides the name on every sign-in (unlike Apple).
        let name = result.user.profile?.name ?? DisplayNameValidator.defaultName
        try await createOrUpdateUserDoc(uid: user.uid, displayName: name)
        
        // 8. Update Firebase Auth profile display name (for consistency)
        if user.displayName == nil || user.displayName?.isEmpty == true {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
        }
    }
    
    /// Handles a URL callback from Google Sign-In's OAuth redirect.
    /// Call this from `onOpenURL` before checking for deep links.
    /// Returns `true` if the URL was consumed by Google Sign-In.
    func handleGoogleSignInURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        // Sign out of Google SDK (no-op if user signed in via Apple)
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
        logger.info("Signed out")
    }
    
    // MARK: - Account Deletion
    
    /// Deletes the user's account from Firebase Auth and cleans up Firestore data.
    /// Apple requires apps offering Sign in with Apple to also provide account deletion.
    ///
    /// Cleanup order:
    /// 1. Set all user's publishedLists to isActive = false
    /// 2. Delete all user's follows
    /// 3. Delete user's Firestore profile
    /// 4. Revoke provider token (Google disconnect / Apple invalidation)
    /// 5. Delete Firebase Auth account
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthError.notSignedIn
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let uid = user.uid
        
        // 1. Deactivate all published lists (soft delete so followers see "no longer available")
        let listsSnapshot = try await db.collection(Constants.Firestore.publishedListsCollection)
            .whereField("ownerUID", isEqualTo: uid)
            .getDocuments()
        
        let batch = db.batch()
        for doc in listsSnapshot.documents {
            batch.updateData(["isActive": false], forDocument: doc.reference)
        }
        
        // 2. Delete all follows by this user
        let followsSnapshot = try await db.collection(Constants.Firestore.followsCollection)
            .whereField("followerUID", isEqualTo: uid)
            .getDocuments()
        
        for doc in followsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        
        // 3. Delete user profile document
        batch.deleteDocument(db.collection(Constants.Firestore.usersCollection).document(uid))
        
        try await batch.commit()
        logger.info("Firestore cleanup complete for UID: \(uid)")
        
        // 4. Provider-specific cleanup before account deletion
        if user.providerData.contains(where: { $0.providerID == "google.com" }) {
            // Revoke Google access token so the app no longer has access to the user's Google account
            do {
                try await GIDSignIn.sharedInstance.disconnect()
                logger.info("Google provider disconnected for account deletion")
            } catch {
                // Non-fatal — proceed with deletion even if Google disconnect fails
                logger.warning("Google disconnect failed: \(error.localizedDescription)")
            }
        } else if user.providerData.contains(where: { $0.providerID == "apple.com" }) {
            // Apple credential is invalidated when the Firebase account is deleted.
            // Token revocation would require re-authentication which is disruptive.
            logger.info("Apple provider found for deletion — credential invalidated with account")
        }
        
        // 5. Delete Firebase Auth account
        try await user.delete()
        logger.info("Firebase Auth account deleted for UID: \(uid)")
    }
    
    // MARK: - Display Name Management
    
    /// Updates the user's display name in Firestore and propagates to published lists.
    func updateDisplayName(_ newName: String) async throws {
        guard let uid = currentUser?.uid else {
            throw AuthError.notSignedIn
        }
        
        // Validate
        let validatedName = try nameValidator.validate(newName)
        
        // Update users doc
        try await db.collection(Constants.Firestore.usersCollection).document(uid).updateData([
            "displayName": validatedName,
            "displayNameLowercase": validatedName.lowercased()
        ])
        
        // Propagate to all published lists owned by this user
        let listsSnapshot = try await db.collection(Constants.Firestore.publishedListsCollection)
            .whereField("ownerUID", isEqualTo: uid)
            .getDocuments()
        
        if !listsSnapshot.documents.isEmpty {
            let batch = db.batch()
            for doc in listsSnapshot.documents {
                batch.updateData(["ownerDisplayName": validatedName], forDocument: doc.reference)
            }
            try await batch.commit()
        }
        
        // Update local state
        displayName = validatedName
        
        // Update Firebase Auth profile too
        let changeRequest = currentUser?.createProfileChangeRequest()
        changeRequest?.displayName = validatedName
        try await changeRequest?.commitChanges()
        
        logger.info("Display name updated to: \(validatedName)")
    }
    
    // MARK: - Firestore User Document
    
    /// Creates the user doc if it doesn't exist, or updates lastActiveAt if it does.
    /// On first creation, sets the display name from the auth provider's response.
    private func createOrUpdateUserDoc(uid: String, displayName: String) async throws {
        let docRef = db.collection(Constants.Firestore.usersCollection).document(uid)
        let doc = try await docRef.getDocument()
        
        if doc.exists {
            // Returning user — update last active timestamp
            try await docRef.updateData([
                "lastActiveAt": FieldValue.serverTimestamp()
            ])
            // Load their stored display name
            await loadDisplayName(for: uid)
        } else {
            // New user — create profile
            try await docRef.setData([
                "displayName": displayName,
                "displayNameLowercase": displayName.lowercased(),
                "createdAt": FieldValue.serverTimestamp(),
                "lastActiveAt": FieldValue.serverTimestamp()
            ])
            self.displayName = displayName
        }
    }
    
    /// Loads the display name from the Firestore user document.
    private func loadDisplayName(for uid: String) async {
        do {
            let doc = try await db.collection(Constants.Firestore.usersCollection).document(uid).getDocument()
            if let name = doc.data()?["displayName"] as? String {
                displayName = name
            } else {
                displayName = DisplayNameValidator.defaultName
            }
        } catch {
            logger.error("Failed to load display name: \(error.localizedDescription)")
            displayName = DisplayNameValidator.defaultName
        }
    }
    
    // MARK: - Nonce Helpers
    
    /// Generates a random string used as a nonce for Sign in with Apple.
    /// Adapted from Firebase documentation.
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            // Fallback to UUID-based nonce if SecRandom fails (extremely unlikely)
            logger.warning("SecRandomCopyBytes failed, using UUID fallback")
            return UUID().uuidString + UUID().uuidString
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    /// SHA256 hash of the nonce string, returned as a hex string.
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Error Types
    
    enum AuthError: LocalizedError {
        case invalidCredential
        case missingIdentityToken
        case missingGoogleClientID
        case noRootViewController
        case notSignedIn
        case cancelled
        case accountExistsWithDifferentProvider
        
        var errorDescription: String? {
            switch self {
            case .invalidCredential:
                return "Unable to process sign-in credential."
            case .missingIdentityToken:
                return "Sign-in did not return an identity token."
            case .missingGoogleClientID:
                return "Google Sign-In is not configured correctly."
            case .noRootViewController:
                return "Unable to present sign-in. Please try again."
            case .notSignedIn:
                return "You must be signed in to perform this action."
            case .cancelled:
                return "Sign-in was cancelled."
            case .accountExistsWithDifferentProvider:
                return "An account with this email already exists using a different sign-in method. Please use the original method you signed in with."
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            signInContinuation?.resume(returning: authorization)
            signInContinuation = nil
        }
    }
    
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if (error as? ASAuthorizationError)?.code == .canceled {
                signInContinuation?.resume(throwing: AuthError.cancelled)
            } else {
                signInContinuation?.resume(throwing: error)
            }
            signInContinuation = nil
        }
    }
}

