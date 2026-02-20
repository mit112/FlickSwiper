import SwiftUI
import AuthenticationServices

/// Reusable view prompting the user to sign in with Apple.
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
                
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { _ in
                    // The actual auth flow is handled by AuthService.
                    // This button is just for visual consistency — we trigger via AuthService.
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .padding(.horizontal, 40)
                .hidden() // Hidden: we use a custom button that calls AuthService
                
                // Actual sign-in button
                Button {
                    performSignIn()
                } label: {
                    HStack(spacing: 8) {
                        if isSigningIn {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "apple.logo")
                        }
                        Text(isSigningIn ? "Signing In..." : "Sign in with Apple")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(.black, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSigningIn)
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
    
    private func performSignIn() {
        isSigningIn = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.signInWithApple()
                dismiss()
                onSignedIn?()
            } catch let error as AuthService.AuthError where error == .cancelled {
                // User cancelled — silently dismiss, don't show error
                isSigningIn = false
            } catch {
                errorMessage = error.localizedDescription
                isSigningIn = false
            }
        }
    }
}
