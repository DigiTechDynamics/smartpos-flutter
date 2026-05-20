# SmartPOS

## Project Description
SmartPOS is an offline-first, native retail Point of Sale (POS) application designed to facilitate robust cart management, real-time sales transactions, inventory tracking, and business analytics. It targets physical retail environments where internet connectivity may be intermittent. The application utilizes a local-first database to perform all critical business functions instantly and caches sync events for eventual synchronization with a centralized cloud backend.

## Tech Stack
- **Framework**: Flutter (Dart 3)
- **Architecture**: Clean Architecture (Data, Domain, Presentation layers)
- **State Management**: `flutter_bloc`
- **Dependency Injection**: `get_it`
- **Database (Local)**: `drift` (SQLite) utilizing `sqlite3_flutter_libs`
- **Hardware Integration**:
  - `flutter_bluetooth_serial` (Thermal Receipt Printing via ESC/POS)
  - `barcode_scan2` & `qr_flutter` (Barcode/QR scanning and generation)
- **Storage**: `shared_preferences`, `flutter_secure_storage` (Session tokens and configurations)

## System Audit

### Architecture & Organization
The system adheres strictly to Clean Architecture, creating a robust separation between UI (Widgets/BLoCs), business logic (UseCases), and data access (Repositories).
- **Domain Layer**: Contains abstractions for all repositories (`AuthRepository`, `SaleRepository`, `InventoryRepository`) and self-contained Use Cases (`CreateSaleUseCase`, `AdjustStockUseCase`).
- **Data Layer**: Implements the Drift ORM schema consisting of 11 distinct, interconnected tables (Users, Products, Inventory, Sales, SaleItems, SyncQueue, etc.).
- **Presentation Layer**: Built on a BLoC-driven, event-state reactive UI, ensuring smooth localized state transitions for high-performance, fast-paced retail operations.

---

### What is There (Completed)
- ✅ **Database Infrastructure**: Fully realized Drift schema supporting offline relationships between products, inventory, transactions, and store configurations.
- ✅ **Use Case Implementations**: Comprehensive domain use cases handling atomic operations, such as finalizing a sale (deducting stock + logging transaction simultaneously) and voiding past sales.
- ✅ **State Management (BLoCs)**:
  - `AuthBloc`: Robust authentication, PIN verification, and session management.
  - `SaleBloc`: Cart item operations, dynamic tax/discount calculations, and checkout workflows.
  - `ReportsBloc`: Automated generation of daily sales reports and metrics summaries directly from the local SQLite database.
- ✅ **Testing Setup**: Extensive unit test suites built out for the Domain Use Cases and Presentation BLoCs, currently successfully passing all 27 critical business logic tests.
- ✅ **Hardware Services**: An integrated `BluetoothService` capable of discovering bonded devices, managing connections, and sending ESC/POS byte commands for physical receipt printing.

---

### What is Missing (To Be Addressed)
- ❌ **Web Compilation Friction**: The Web compiler rejects the native FFI elements of our SQLite setup. To achieve stable Flutter Web deployment, a dedicated `WasmDatabase` integration (including setting up web workers and `sqlite3.wasm` binaries) must be configured in `app_database.dart`.
- ❌ **Windows Developer Mode Issues**: Native desktop compilation on Windows fails gracefully if Developer Mode (symlink support) is disabled. This is an environment issue, but it acts as a recurring friction point for developers.
- ❌ **Cloud Sync Execution**: The `SyncQueue` tracks offline modifications successfully at a database level, but the `SyncService` requires the final API logic to actively POST those cached modifications up to the remote cloud (e.g., Supabase, Firebase) when a connection is restored.
- ❌ **End-to-End Hardware Testing**: While unit tests successfully validate the theoretical logic of the Bluetooth and barcode scanning code, physical End-to-End (E2E) integration testing on a real Android POS terminal is required to fine-tune printer byte configurations and scanner response times.
