# SubsHero Technical Context

## 🛠️ Technology Stack Overview

SubsHero is built using a modern technology stack that prioritizes performance, type safety, and developer experience. The application follows a client-server architecture with a React frontend and Laravel backend, connected via RESTful APIs.

## 📱 Frontend Technologies

### Core Framework
- **Framework**: React 19.1.0 with TypeScript 5.4.2
- **Build System**: Vite 5.2.0 for fast development and optimized production builds
- **Type Safety**: TypeScript with strict mode enabled for robust type checking

### State Management
- **Global State**:
  - Zustand 5.0.4 for global state management with request deduplication
  - React Context API for component-specific state
- **Form State**:
  - React Hook Form 7.56.2 for performant form handling
  - Zod 3.22.4 for schema validation and type inference

### UI Components & Styling
- **Component Library**:
  - shadcn/ui (built on Radix UI primitives) for accessible, customizable components
  - Tailwind CSS 3.4.1 for utility-first styling
  - Lucide React 0.475.0 for consistent iconography
  - Tailwind Merge 2.2.1 for conditional class merging
- **Animation**:
  - Framer Motion 11.0.8 for smooth animations and transitions
  - CSS transitions for simpler animations

### Data Visualization & Display
- **Charts & Graphs**:
  - Recharts 2.15.3 for responsive, customizable charts
  - FullCalendar 6.1.17 for calendar views and date-based visualization
- **Tables & Lists**:
  - TanStack Table 8.21.3 (React Table v8) for advanced table functionality
  - Virtualized lists for handling large datasets efficiently

### User Experience Enhancements
- **File Handling**:
  - FilePond 7.1.3 for intuitive file uploads with preview
- **Notifications**:
  - Sonner 2.0.3 for toast notifications (primary)
  - React Hot Toast 2.5.2 as alternative implementation
- **Interaction**:
  - dnd-kit for accessible drag and drop functionality
  - Keyboard navigation support throughout the application
- **Date Handling**:
  - date-fns 4.1.0 for comprehensive date manipulation
  - React Day Picker 9.6.7 for user-friendly date selection

### Developer Tools
- **Code Quality**:
  - ESLint with TypeScript and React plugins for code quality
  - Prettier for consistent code formatting
  - Total TypeScript linter standards for type safety
- **Testing**:
  - Vitest for unit and integration testing
  - Testing Library for component testing
  - Cypress for end-to-end testing

## 🖥️ Backend Technologies

### Core Framework
- **Framework**: Laravel 12.9.2 for robust PHP backend development
- **PHP Version**: PHP 8.3 with strict typing and modern language features

### API & Data Layer
- **API Generation**:
  - Laravel Orion for standardized RESTful API generation
  - Custom middleware for request validation and transformation
- **Server-Side Rendering**:
  - Inertia.js for hybrid SPA/server-rendered application
- **Database**:
  - MySQL (MariaDB 11.8.1) as primary database
  - Eloquent ORM for database interactions
  - Database migrations for version-controlled schema changes
- **Caching**:
  - Redis for high-performance caching
  - Laravel's built-in cache abstraction

### Security & Authentication
- **Authentication**:
  - Laravel's web guard for secure API authentication
  - CSRF protection for all form submissions
  - Rate limiting for API endpoints
- **Authorization**:
  - Policy-based authorization for fine-grained access control
  - Role-based permissions system

### Testing & Quality Assurance
- **Testing Framework**:
  - Pest PHP for expressive, elegant testing
  - Laravel's testing utilities for HTTP and database testing
  - Mockery for mocking dependencies in tests
- **Code Quality**:
  - PHP_CodeSniffer for code style enforcement
  - PHPStan for static analysis

### Documentation & Developer Experience
- **API Documentation**:
  - Scribe for comprehensive, interactive API documentation
  - OpenAPI/Swagger specification generation
- **Development Tools**:
  - Laravel Tinker for interactive REPL
  - Laravel Telescope for debugging and monitoring

## 🛠️ Development Environment & Workflow

### Local Development Setup
- **Server Environment**:
  - Laragon for Windows development environment
  - Docker containers for consistent development environments (planned)
- **Development Servers**:
  - Frontend Dev Server: Vite (`npm run dev`) with hot module replacement
  - Backend Server: PHP built-in server via Laragon
  - Queue Worker: Laravel queue worker for background jobs (`php artisan queue:listen`)
- **Combined Commands**:
  - `composer dev` (runs server, queue, and Vite concurrently)
  - `npm run dev:all` (alternative command for full development environment)

### Build & Deployment Process
- **Frontend Build**:
  - Development: `npm run dev` for local development
  - Production: `npm run build` for optimized Vite build
  - Type Checking: `npm run types` for TypeScript validation
- **Backend Build**:
  - `composer install --optimize-autoloader --no-dev` for production
  - `php artisan config:cache` and `php artisan route:cache` for performance
- **Environment Configuration**:
  - Development URL: https://subsheroload.test/
  - Database: subshero_db (MariaDB)
  - Environment variables managed via .env files

### Code Quality & Standards
- **Frontend Quality Tools**:
  - ESLint with React and React Hooks plugins for code quality
  - Prettier with plugins for Tailwind CSS and import organization
  - Total TypeScript linter standards for type safety
  - Husky for pre-commit hooks
- **Backend Quality Tools**:
  - PHP_CodeSniffer for PSR-12 compliance
  - PHPStan for static analysis
  - Laravel Pint for code style enforcement
- **Documentation Standards**:
  - JSDoc for frontend code documentation
  - PHPDoc for backend code documentation
  - README files for component and module documentation

## 🚧 Technical Constraints & Requirements

### Performance Requirements
- **Data Volume**:
  - Must handle users with hundreds of subscriptions efficiently
  - Support pagination and virtualization for large datasets
- **API Response Time**:
  - API endpoints should respond within 500ms for standard operations
  - Batch operations may take up to 2 seconds for completion
- **Page Load Time**:
  - Initial page load should be under 2 seconds
  - Subsequent navigation should be near-instantaneous
- **Bundle Size**:
  - Frontend bundle size should be optimized for quick loading
  - Code splitting for route-based chunking
  - Tree-shaking to eliminate unused code
- **Network Traffic**:
  - Minimize API calls through request deduplication
  - Implement client-side caching for frequently accessed data
  - Use client-side operations for filtering, sorting, and pagination

### Security Requirements
- **Authentication**:
  - Must use secure authentication methods with HTTPS
  - Implement proper session management and token handling
- **Data Protection**:
  - User data must be protected and not accessible by other users
  - Implement proper database access controls
- **Input Validation**:
  - All user inputs must be validated on both client and server
  - Use Zod schemas for consistent validation across frontend and backend
- **CSRF Protection**:
  - Must implement CSRF protection for all forms
  - Use Laravel's built-in CSRF protection mechanisms
- **API Security**:
  - Implement rate limiting to prevent abuse
  - Proper error handling to avoid information leakage

### Compatibility & Accessibility Requirements
- **Browser Support**:
  - Must support modern browsers (Chrome, Firefox, Safari, Edge)
  - Graceful degradation for older browsers
- **Responsive Design**:
  - Must work seamlessly on desktop, tablet, and mobile devices
  - Implement mobile-first design principles
- **Accessibility**:
  - Must meet WCAG 2.1 AA standards
  - Implement proper keyboard navigation
  - Ensure screen reader compatibility
  - Maintain sufficient color contrast ratios

## 📦 Dependencies & Package Management

### Frontend Dependencies
Key dependencies from package.json:
- **Core Framework**:
  - React and React DOM (v19.1.0)
  - TypeScript (v5.4.2)
  - Vite (v5.2.0)
- **UI & Styling**:
  - Tailwind CSS (v3.4.1)
  - Radix UI components (various versions)
  - shadcn/ui (custom components based on Radix)
  - Lucide React (v0.475.0)
- **Data Management**:
  - TanStack Table (v8.21.3)
  - Zustand (v5.0.4)
  - React Query (v5.17.19)
- **Form Handling**:
  - React Hook Form (v7.56.2)
  - Zod (v3.22.4)
- **Utilities**:
  - FilePond (v7.1.3)
  - FullCalendar (v6.1.17)
  - date-fns (v4.1.0)
  - Recharts (v2.15.3)
  - clsx (v2.1.0)
  - tailwind-merge (v2.2.1)

### Backend Dependencies
Key dependencies from composer.json:
- **Core Framework**:
  - Laravel Framework (v12.9.2)
  - PHP (v8.3)
- **API & Routing**:
  - Laravel Orion (v3.1.0)
  - Inertia Laravel (v1.0.0)
  - Ziggy (v2.0.0)
- **Development & Debugging**:
  - Laravel Tinker (v2.9.0)
  - Laravel Telescope (v5.0.0)
- **Documentation**:
  - Scribe (v4.29.0)
- **Testing**:
  - Pest PHP (v2.34.0)
  - Mockery (v1.6.7)

### Package Management Strategy
- **Frontend**:
  - Use npm for package management
  - Lock file (package-lock.json) committed to version control
  - Regular dependency updates with security patches prioritized
  - Avoid direct editing of package.json for dependency management
- **Backend**:
  - Use Composer for package management
  - Lock file (composer.lock) committed to version control
  - Regular dependency updates with security patches prioritized

## 🗄️ Database Schema & Data Model

The application uses a relational database schema with carefully designed tables and relationships to support all functionality while maintaining data integrity and performance.

### Core Tables
1. **users**: Stores user account information and preferences
   - Primary user data including authentication details
   - User preferences and settings
   - Account status and subscription tier

2. **subs_subscriptions**: Central table for subscription management
   - Core subscription details (name, amount, currency)
   - Subscription status (active, paused, cancelled)
   - Renewal information (frequency, next payment date)
   - Special flags (e.g., sub_ltd for lifetime deals)
   - Foreign keys to related entities (folder_id, category_id, payment_method_id)

3. **subs_folders**: Organizational structure for subscriptions
   - Folder name and description
   - User-specific folder settings
   - Hierarchical structure (parent_id for nested folders)

4. **subs_paymethods**: Payment method information
   - Payment method details (name, type, last four digits)
   - Expiration dates for cards
   - User-specific payment method settings

### Transaction & Financial Tables
5. **subs_transactions**: Financial transaction records
   - Transaction amount and currency
   - Transaction date and status
   - Foreign keys to subscription and payment method
   - Transaction type and category

### Notification & Reminder Tables
6. **subs_reminders**: Individual reminder instances
   - Reminder date and status
   - Notification method and delivery status
   - Foreign keys to subscription and reminder profile

7. **users_reminder_profiles**: User-defined reminder templates
   - Reminder timing preferences (days before renewal)
   - Notification method preferences
   - Default reminder settings

### Product & Categorization Tables
8. **products**: Product information for subscriptions
   - Product details (name, description, logo)
   - Product categorization
   - Default pricing information

9. **product_pricingplans**: Pricing plans for products
   - Plan details (name, price, billing frequency)
   - Plan status and availability
   - Foreign key to product

10. **products_categories**: Categorization for products
    - Category name and description
    - Hierarchical structure (parent_id for nested categories)

### Administrative Tables
11. **admin_users**: Administrative user accounts
    - Admin user details and permissions
    - Role-based access control information

12. **app_settings**: Application-wide settings
    - System configuration parameters
    - Feature flags and global settings

## 🔌 API Architecture & Integration

### RESTful API Design
- **API Architecture**: RESTful API built with Laravel Orion for automatic endpoint generation
- **Authentication**: Laravel's web guard with session-based authentication
- **Request Flow**:
  1. Frontend service layer makes HTTP requests to API endpoints
  2. Laravel routes map requests to appropriate controllers
  3. Orion controllers handle request processing and response generation
  4. Eloquent models interact with the database

### Core API Endpoints

1. **Subscription Management**:
   - `GET /api/subscriptions` - List subscriptions with filtering, sorting, and pagination
   - `POST /api/subscriptions` - Create new subscription
   - `GET /api/subscriptions/{id}` - Get detailed subscription information
   - `PUT /api/subscriptions/{id}` - Update subscription details
   - `DELETE /api/subscriptions/{id}` - Delete subscription
   - `GET /api/subscriptions/extended` - Get subscriptions with related entities (optimized endpoint)
   - `POST /api/subscriptions/{id}/clone` - Clone existing subscription
   - `POST /api/subscriptions/{id}/cancel` - Cancel subscription

2. **Transaction Management**:
   - `GET /api/transactions` - List transactions with filtering and pagination
   - `POST /api/transactions` - Record new transaction
   - `GET /api/transactions/{id}` - Get transaction details
   - `PUT /api/transactions/{id}` - Update transaction information
   - `DELETE /api/transactions/{id}` - Delete transaction record

3. **Organization & Categorization**:
   - `GET /api/folders` - List folders
   - `POST /api/folders` - Create folder
   - `PUT /api/folders/{id}` - Update folder
   - `DELETE /api/folders/{id}` - Delete folder
   - `GET /api/categories` - List categories

### API Implementation Details

- **Organization**: Controllers organized by domain (User vs Admin) in `app/Http/Controllers/Api/`
- **Controller Structure**:
  - Base controllers extend Laravel Orion's `Controller` class
  - Controllers define exposed models, relationships, and permissions
  - Custom methods override default behavior when needed
  - Some controllers implement beforeStore method to handle user_id consistently

### Frontend API Integration
- **Service Layer Pattern**: Centralized API services in `resources/js/services/api/`
- **Request Deduplication**: Preventing duplicate API calls using static properties on Zustand store functions
- **Client-side Caching**: Using in-memory caching to avoid redundant API calls
- **Client-side Operations**: Performing filtering, sorting, and pagination client-side to reduce network traffic
- **Zustand State Management**: Implementing proper dependency tracking to prevent useEffect from triggering redundant API calls
- **Direct Store Access Pattern**: Components access Zustand stores directly instead of through intermediate hooks
- **Error Handling**: Standardized error handling with toast notifications

### API Response Format
- **Standardized Structure**: Consistent JSON response format across all endpoints
- **Pagination**: Server-side pagination for large datasets
- **Relationships**: Support for eager loading related models via `include` parameter
- **Filtering**: Advanced filtering capabilities via query parameters
- **Sorting**: Customizable sorting via query parameters

### API Documentation
- **Documentation Tool**: Scribe for comprehensive API documentation
- **Interactive Testing**: Interactive API testing interface for developers
- **Automatic Generation**: Documentation automatically generated from code annotations

### Future External API Integrations

The application is designed to support future integrations with external services:

1. **Payment Gateway Integration**:
   - Stripe, PayPal, and other payment processors for automatic payment tracking
   - Subscription management APIs for automatic renewal detection

2. **Notification Services**:
   - Email service providers for transactional emails
   - Push notification services for mobile alerts

3. **Calendar & Productivity Integration**:
   - Google Calendar, Apple Calendar for adding renewal dates
   - Productivity tools for task management

## 🚀 Deployment Strategy & DevOps

### Hosting Infrastructure
- **Web Application**: Hosted on standard PHP/MySQL hosting environment
- **Server Requirements**:
  - PHP 8.3+ with required extensions
  - MySQL/MariaDB 11.0+
  - Apache or Nginx web server with proper rewrite rules
- **Asset Delivery**:
  - Static assets served through CDN for improved performance
  - Optimized asset caching strategies

### CI/CD Pipeline
- **Automated Testing**:
  - Unit and feature tests with Pest PHP
  - Frontend component testing
  - End-to-end testing for critical user journeys
- **Code Quality**:
  - Automated code quality checks with ESLint and TypeScript
  - Static analysis for PHP code
  - Coding standards enforcement
- **Build Process**:
  - Frontend build process with Vite
  - Asset optimization and minification
  - Automated versioning

### Monitoring & Observability
- **Error Tracking**:
  - Comprehensive error logging and monitoring
  - Real-time error notifications
  - Error categorization and prioritization
- **Performance Monitoring**:
  - API endpoint performance tracking
  - Database query monitoring
  - Frontend performance metrics
- **Network Analysis**:
  - Network traffic monitoring to identify duplicate API calls
  - Bandwidth optimization
  - Request/response time analysis

## 🔍 Technical Debt & Roadmap

### Current Technical Debt
- **Data Model Issues**:
  - Some code still uses deprecated payment_method field instead of payment_method_id
  - Inconsistent relationship naming across models
- **Component Architecture**:
  - Some components may need refactoring for better reusability
  - Performance optimizations needed for other pages beyond the subscription listing page
  - Improved error handling and validation required
- **Performance Concerns**:
  - Duplicate API calls in some components (being addressed systematically with direct store access pattern)
  - Inefficient data fetching patterns in some areas

### Current Limitations
- **Integration Capabilities**:
  - No direct integration with subscription services
  - Manual data entry required for most operations
- **User Experience**:
  - Limited offline capabilities
  - Some views need improved mobile responsiveness
  - No dark mode support currently
- **Data Management**:
  - Limited import/export functionality
  - No bulk operations for managing multiple subscriptions

### Roadmap & Planned Improvements

#### Short-term (Next 3 Months)
- **Architecture Standardization**:
  - Complete standardization on Zustand for state management across all components
  - Implement consistent form handling with React Hook Form and Zod
  - Optimize API calls with request deduplication and caching
- **Performance Optimization**:
  - Reduce duplicate API calls through store pattern implementation
  - Implement client-side filtering, sorting, and pagination
  - Optimize bundle size through code splitting

#### Medium-term (3-6 Months)
- **User Experience Enhancements**:
  - Improve mobile responsiveness across all views
  - Add dark mode support
  - Implement CSV import/export functionality
  - Enhance data visualization components

#### Long-term (6-12 Months)
- **Advanced Features**:
  - Implement offline support for basic functionality
  - Add multi-language support
  - Develop integrations with external subscription services
  - Create native mobile applications

## 🚀 Performance Optimization Patterns

### Request Deduplication
- **Implementation Strategy**:
  - Using static properties on Zustand store functions to track in-flight requests
  - Returning the same promise for concurrent calls to the same endpoint
  - Implementing proper cleanup in finally blocks
- **Benefits**:
  - Reduced network traffic
  - Improved application responsiveness
  - Decreased server load

### Client-side Caching
- **Implementation Strategy**:
  - Caching API responses in memory
  - Checking cache before making new API calls
  - Implementing cache invalidation strategies
- **Benefits**:
  - Faster data access
  - Reduced API calls
  - Improved offline capabilities

### Client-side Operations
- **Implementation Strategy**:
  - Performing filtering, sorting, and pagination client-side
  - Updating the UI without making new API calls
  - Using proper dependency arrays in useEffect hooks
- **Benefits**:
  - Immediate user feedback
  - Reduced server load
  - Better user experience

### Direct Store Access
- **Implementation Pattern**:
  - Components access Zustand stores directly instead of through intermediate hooks
  - Filter values accessed through the `filters` object (e.g., `filters.activeTab`)
  - Filter values set using the `setFilter` method (e.g., `setFilter('activeTab', tab)`)
- **Benefits**:
  - Eliminates unnecessary abstraction layers that can cause refresh errors
  - Provides a single source of truth for component state
  - Improves code maintainability and debugging

### Data Prefetching
- Fetching all needed data in a single API call
- Using eager loading to include related data
- Structuring API responses to minimize the need for additional calls

This document provides technical context for the SubsHero application, including technologies used, development setup, constraints, dependencies, and other technical considerations. It serves as a reference for understanding the technical foundation of the project.
