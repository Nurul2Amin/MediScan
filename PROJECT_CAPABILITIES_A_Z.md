# Prescription Scanner & Pharmacy Inventory System - A-Z Capabilities

## 1. Project Overview
This application is a dual-role mobile platform designed to bridge the gap between patients and pharmacies. It serves two primary purposes:
1.  **For Patients**: Scanning prescriptions to find availability at nearby pharmacies, managing health shopping via a cart, and finding medicines.
2.  **For Pharmacy Owners**: A comprehensive inventory management system (IMS) with AI-powered stock entry, batch tracking, expiry management, and sales monitoring.

**Version:** 1.0.0+1
**Tech Stack:**
*   **Frontend**: Flutter (Riverpod for state management, GoRouter for navigation).
*   **Backend**: Supabase (PostgreSQL, Auth, Realtime).
*   **AI/Intelligence**: Google Gemini (via Supabase Edge Functions) for OCR and text parsing.
*   **Maps**: `flutter_map` (OpenStreetMap) + `geolocator`.

---

## 2. Authentication & Roles
The system is built on a robust role-based access control (RBAC) model.

### Features:
*   **Dual Sign-Up Flow**: Users select their role (`customer` or `pharmacy_owner`) during registration.
*   **Immutable Roles**: Once set, roles cannot be changed to prevent security breaches.
*   **Profile Management**: users can manage personal details and app preferences.
*   **Smart Redirection**:
    *   `Customers` -> Redirected to Home/Map.
    *   `Owners` -> Redirected to Owner Dashboard.
    *   Unauthenticated users -> Redirected to Login.

---

## 3. Customer Capabilities (Patient App)
The customer-facing side focuses on ease of access to medication.

### A. Medicine Search & Scanning
*   **Prescription OCR**: Users can take a photo of a prescription. The app uses **Gemini AI** (Edge Function `ai_extract_medicines`) to parse handwritten or printed text into a list of search terms.
*   **Manual Search**: Search for medicines by brand or generic name using `medicine_repository`.
*   **Results Page**: detailed list of found medicines with availability status.

### B. Pharmacy Finder & Map
*   **Geolocation-Based Search**: Finds pharmacies within a user-defined radius.
*   **Interactive Map**: Visualizes pharmacies using OpenStreetMap (OSM).
*   **Filtering & Sorting**:
    *   **Sort By**: Balanced, Nearest, Cheapest, or Most Matched items.
    *   **Filters**: "Require full match" (only show pharmacies with ALL items).
    *   **Custom Radius**: Adjustable via Settings (1km - 20km).

### C. Shopping Experience
*   **Cart System**: Add items to a cart, view total estimated price, and prepare orders.
*   **Pharmacy Details**: View specific pharmacy info, available stock, and contact details.

### D. User Preferences
*   **Global Settings**: Users can save their default search radius, sorting preference, and max result limits (`settings_provider.dart`), which persists across sessions via Supabase.

---

## 4. Pharmacy Owner Capabilities (Inventory System V2)
A professional-grade inventory system designed to modernize pharmacy operations.

### A. Owner Dashboard
*   **Quick Actions**: Shortcuts to "Stock In", "Quick Stock Out", and "Expiry Dashboard".
*   **Alerts**: Visual indicators for low stock and expiring batches.

### B. Intelligent Inventory Management (V2)
The core of the owner app is the **Inventory V2** system, which supports:
*   **Batch Tracking**: detailed tracking of medicines by Batch Number and Expiry Date.
*   **First-Expired-First-Out (FEFO)**: Automated logic to suggest selling closest-expiry batches first.
*   **Unit Conversions**: Handles complex pharmacy units (e.g., Box -> Strip -> Tablet) automatically.
*   **Ledger System**: audit trail of all stock movements (Stock In, Sale, Adjustment, Return).

### C. AI-Powered Stock Entry ("Stock In")
*   **Scan to Stock**: Owners can snap a picture of medicine packaging.
*   **AI Parsing**: Edge function `ai_extract_pack_hint` detects specific pack details (e.g., "10 tabs per strip") to auto-populate unit conversion factors.
*   **Text Parsing**: Copy-paste invoices or raw text, and `ai_parse_stock_text` will structure it into inventory items.

### D. Expiry Management
*   **Expiry Dashboard**: dedicated view to track batches nearing expiration.
*   **Color-Coded statuses**: Visual warnings for "Expired", "Expiring Soon" (e.g., <3 months), and "Good".

---

## 5. Technical Architecture

### Data Layer (`lib/data`)
*   **Repositories**:
    *   `InventoryRepository`: complex operations for batch merging, stock deductions, and ledger writes.
    *   `PharmacyRepository`: Spatial queries for finding nearby stores.
    *   `MedicineRepository`: Master database of medicine names/generics.
*   **Models**: Strongly typed Dart objects mirroring Supabase tables (`InventoryBatch`, `UserProfile`).

### Presentation Layer (`lib/presentation`)
*   **State Management**: `flutter_riverpod` handles reactive state (e.g., `cartProvider`, `settingsProvider`).
*   **Routing**: `go_router` manages deep linking and guarded routes.
*   **Pages**: Organized by feature (`/owner`, `/home`, `/scan`).

### Edge Functions (Server-Side Logic)
*   `ai_extract_medicines`: Vision API for prescriptions.
*   `ai_parse_stock_text`: NLP for bulk text entry.
*   `ai_extract_pack_hint`: Vision API for packaging details.
*   **Privacy**: API keys (Gemini) are kept secure on the server, never exposed to the Flutter client.

---

## 6. Directory Structure Guide
*   `lib/config`: App-wide configuration (Env, Router, Theme).
*   `lib/data`: Data logic, models, and repositories.
*   `lib/presentation`: UI code.
    *   `pages/auth`: Login/Signup.
    *   `pages/owner`: Inventory & Dashboard.
    *   `pages/home`: Customer search & landing.
    *   `pages/pharmacy`: Map & Finder.
    *   `delegates`: Search delegates.
    *   `widgets`: Reusable components.

