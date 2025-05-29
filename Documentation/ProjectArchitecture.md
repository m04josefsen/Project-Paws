# Project Paws - Architecture

-- **View (PetView, PetWindow): How things look and are presented.**
-- **ViewModel (PetViewModel): The state and logic of the pet, UI-independent.**
-- **Controller/Coordinator (AppDelegate): Application lifecycle, high-level UI setup, and routing user actions to the ViewModel.**
-- **Model (Enums PetType, PetState): Define the structure of the data.**
-- **SwiftUI App Lifecycle (ProjectPawsApp): Modern app entry point and scene management, delegating to AppKit components where necessary.**

## Project Flow
ProjectPawsApp (entry) -> uses AppDelegate -> AppDelegate sets up UI (NSStatusItem, PetWindow with PetView) and owns PetViewModel -> PetView displays what PetViewModel dictates -> User interacts with menu (AppDelegate -> PetViewModel) or PetView (PetView -> PetViewModel) -> PetViewModel updates state -> PetView and AppDelegate (menu) react to PetViewModel changes.
