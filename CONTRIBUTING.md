# Contributing to FlickSwiper

Thanks for your interest in contributing! Here's how to get started.

## Getting Started

1. Fork the repo and clone your fork
2. Set up the project following the [README](README.md#getting-started)
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Test on a simulator and/or device
6. Commit with a clear message: `git commit -m "Add: brief description"`
7. Push and open a Pull Request

## Guidelines

- Follow existing code style and naming conventions
- Add `///` doc comments to new public types and methods
- Keep `print()` statements wrapped in `#if DEBUG`
- Test on iOS 17+ simulator before submitting
- One feature or fix per PR
- Use intent-focused commit messages (e.g. `Fix: fail CI on xcodebuild errors` instead of generic messages like `update` or `rename`)

## Reporting Issues

Open an issue with a clear title and include:
- What you expected to happen
- What actually happened
- Steps to reproduce
- iOS version and device/simulator

## Code of Conduct

Be respectful and constructive. We're all here to build something cool.
