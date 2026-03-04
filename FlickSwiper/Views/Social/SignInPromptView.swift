import SwiftUI
import AuthenticationServices

/// Reusable view prompting the user to sign in (Apple or Google).
/// Shown when auth is required for social features (publish, follow).
///
/// Usage:
/// ```
/// .sheet(isPresented: $showSignIn) {
///     SignInPromptView(reason: "share lists with friends")
/// }
/// ```
struct SignInPromptView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss
    
    /// Brief explanation of why sign-in is needed, shown below the title.
    /// e.g. "share lists with friends" → "Sign in to share lists with friends"
    var reason: String = "share lists with friends"
    
    /// Called after successful sign-in. The sheet dismisses automatically,
    /// but the caller may want to continue a flow (e.g. publish).
    var onSignedIn: (() -> Void)?
    
    @State private var errorMessage: String?
    @State private var isSigningIn = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                
                VStack(spacing: 8) {
                    Text("Sign In Required")
                        .font(.title2.weight(.bold))
                    
                    Text("Sign in to \(reason). Your account is used only for list sharing — your library stays on your device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // MARK: - Sign-In Buttons
                
                VStack(spacing: 12) {
                    // Apple Sign-In button
                    Button {
                        performAppleSignIn()
                    } label: {
                        HStack(spacing: 8) {
                            if isSigningIn {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "apple.logo")
                            }
                            Text("Sign in with Apple")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.white)
                        .background(.black, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isSigningIn)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(.quaternary)
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(.quaternary)
                    }
                    
                    // Google Sign-In button
                    Button {
                        performGoogleSignIn()
                    } label: {
                        HStack(spacing: 8) {
                            if isSigningIn {
                                ProgressView()
                                    .tint(.primary)
                            } else {
                                // Google "G" branding
                                Text("G")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.blue)
                            }
                            Text("Sign in with Google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                    }
                    .disabled(isSigningIn)
                }
                .padding(.horizontal, 40)
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                Spacer()
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Sign-In Actions
    
    private func performAppleSignIn() {
        isSigningIn = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.signInWithApple()
                dismiss()
                onSignedIn?()
            } catch let error as AuthService.AuthError where error == .cancelled {
                isSigningIn = false
            } catch {
                errorMessage = error.localizedDescription
                isSigningIn = false
            }
        }
    }
    
    private func performGoogleSignIn() {
        isSigningIn = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.signInWithGoogle()
                dismiss()
                onSignedIn?()
            } catch let error as AuthService.AuthError where error == .cancelled {
                isSigningIn = false
            } catch {
                errorMessage = error.localizedDescription
                isSigningIn = false
            }
        }
    }
}
