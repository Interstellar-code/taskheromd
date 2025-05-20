# Database Schema Visualization Template

This document provides a comprehensive visual representation of the database schema using Mermaid diagrams. The diagrams are organized by functional areas to make it easier to understand the relationships between tables.

## Core User Tables

```mermaid
erDiagram
    users ||--o{ user_settings : has
    users ||--o{ user_contacts : has
    users ||--o{ user_plans : has
    users ||--o{ user_profiles : has
    users }|--|| countries : belongs_to
    users ||--o{ orders : places
    users ||--o{ customers : has

    users {
        id bigint PK
        name string
        first_name string
        last_name string
        email string
        email_verified_at timestamp
        phone string
        company_name string
        password string
        remember_token string
        user_type int
        timezone string
        country_id bigint FK
        status boolean
        created_at timestamp
        updated_at timestamp
        deleted_at timestamp
    }

    user_settings {
        id bigint PK
        user_id bigint FK
        active_profile_id bigint FK
        created_at timestamp
        updated_at timestamp
    }

    user_contacts {
        id bigint PK
        user_id bigint FK
        name string
        email string
        status boolean
        created_at timestamp
        updated_at timestamp
    }

    user_plans {
        id bigint PK
        user_id bigint FK
        plan_id bigint FK
        status string
        start_date date
        end_date date
        created_at timestamp
        updated_at timestamp
    }

    user_profiles {
        id bigint PK
        user_id bigint FK
        name string
        settings json
        is_default boolean
        created_at timestamp
        updated_at timestamp
    }
```

## Main Feature Tables

```mermaid
erDiagram
    users ||--o{ folders : has
    users ||--o{ payment_methods : has
    users ||--o{ main_items : has
    folders ||--o{ main_items : contains
    payment_methods ||--o{ main_items : used_by
    user_profiles ||--o{ main_items : applied_to
    main_items }o--o{ categories : belongs_to_many
    main_items }|--|| products : belongs_to
    main_items }|--|| platforms : belongs_to
    main_items }|--|| types : belongs_to
    main_items ||--o{ transactions : has
    main_items ||--o{ reminders : has
    main_items ||--o{ pricing_plans : has
    user_profiles }o--o{ main_items : many_to_many

    folders {
        id bigint PK
        user_id bigint FK
        name string
        description text
        color string
        icon string
        is_default boolean
        created_at timestamp
        updated_at timestamp
    }

    payment_methods {
        id bigint PK
        user_id bigint FK
        name string
        is_default boolean
        created_at timestamp
        updated_at timestamp
    }

    main_items {
        id bigint PK
        user_id bigint FK
        category_id bigint FK
        categories json
        product_id bigint FK
        platform_id bigint FK
        type_id bigint FK
        name string
        description text
        logo json
        favicon json
        next_payment_date date
        start_date date
        folder_id bigint FK
        status string
        payment_method_id bigint FK
        profile_id bigint FK
        auto_renewal boolean
        total_spent decimal
        notes text
        tags json
        is_lifetime boolean
        notifications_enabled boolean
        created_at timestamp
        updated_at timestamp
        deleted_at timestamp
    }

    transactions {
        id bigint PK
        user_id bigint FK
        item_id bigint FK
        amount decimal
        currency string
        payment_date date
        payment_method string
        status string
        notes text
        created_at timestamp
        updated_at timestamp
    }

    reminders {
        id bigint PK
        user_id bigint FK
        item_id bigint FK
        reminder_date date
        status string
        created_at timestamp
        updated_at timestamp
    }

    profile_item {
        id bigint PK
        profile_id bigint FK
        item_id bigint FK
        created_at timestamp
        updated_at timestamp
    }

    pricing_plans {
        id bigint PK
        item_id bigint FK
        plan_name string
        plan_price decimal
        currency_code string
        plan_frequency string
        plan_type string
        refund_days int
        auto_renewal boolean
        is_popular boolean
        description text
        features json
        limitations json
        created_at timestamp
        updated_at timestamp
    }
```

## Product Catalog Tables

```mermaid
erDiagram
    categories ||--o{ products : has
    types ||--o{ products : has
    platforms ||--o{ products : has
    products ||--o{ main_items : used_in
    categories ||--o{ main_items : used_in
    types ||--o{ main_items : used_in
    platforms ||--o{ main_items : used_in

    categories {
        id bigint PK
        name string
        slug string
        description text
        status boolean
        created_at timestamp
        updated_at timestamp
    }

    types {
        id bigint PK
        name string
        slug string
        description text
        status boolean
        created_at timestamp
        updated_at timestamp
    }

    platforms {
        id bigint PK
        name string
        slug string
        description text
        status boolean
        created_at timestamp
        updated_at timestamp
    }

    products {
        id bigint PK
        category_id bigint FK
        name string
        brand string
        type_id bigint FK
        description text
        featured boolean
        rating int
        popularity int
        url string
        mobile_url string
        image json
        status boolean
        is_lifetime boolean
        launch_year int
        platform_id bigint FK
        created_at timestamp
        updated_at timestamp
        favicon json
    }
```

## E-commerce Tables

```mermaid
erDiagram
    plans ||--o{ user_plans : assigned_to
    plans ||--o{ orders : ordered_in
    users ||--o{ customers : has
    customers ||--o{ orders : places

    plans {
        id bigint PK
        name string
        slug string
        description text
        type string
        price_monthly decimal
        price_annually decimal
        lifetime_price decimal
        lifetime_price_date date
        currency string
        limit_items smallint
        limit_folders smallint
        limit_tags smallint
        limit_contacts smallint
        limit_payment_methods smallint
        limit_profiles smallint
        limit_webhooks smallint
        limit_teams smallint
        limit_storage bigint
        is_default boolean
        is_upgradable boolean
        trial_days int
        number_of_users tinyint
        sort int
        status boolean
        product_id int
        variation_id int
        created_at timestamp
        updated_at timestamp
    }

    customers {
        id bigint PK
        user_id bigint FK
        first_name string
        last_name string
        email string
        phone string
        company_name string
        status boolean
        created_at timestamp
        updated_at timestamp
    }

    orders {
        id bigint PK
        customer_id bigint FK
        plan_id bigint FK
        number string
        total_price decimal
        status string
        currency string
        payment_method string
        payment_id string
        transaction_id string
        created_at timestamp
        updated_at timestamp
    }
```

## System Settings Tables

```mermaid
erDiagram
    countries ||--o{ country_timezones : has
    countries ||--o{ users : has
    countries ||--o{ addresses : has
    languages ||--o{ language_translations : has
    currencies ||--o{ currency_rates : has

    countries {
        id bigint PK
        name string
        iso string
        code string
        iso3 string
        numcode string
        phone string
        phonecode string
        currency string
        timezone string
        translations json
        timezones json
        numeric_code string
        nationality string
        capital string
        tld string
        native string
        region string
        currency_name string
        currency_symbol string
        wikiDataId string
        lat decimal
        lng decimal
        emoji string
        emojiU string
        flag boolean
        is_activated boolean
        created_at timestamp
        updated_at timestamp
    }

    country_timezones {
        id bigint PK
        country_id bigint FK
        timezone string
        gmt_offset string
        gmt_offset_name string
        abbreviation string
        timezone_name string
        created_at timestamp
        updated_at timestamp
    }

    languages {
        id bigint PK
        name string
        code string
        native string
        rtl boolean
        status boolean
        created_at timestamp
        updated_at timestamp
    }

    language_translations {
        id bigint PK
        language_id bigint FK
        key string
        value text
        created_at timestamp
        updated_at timestamp
    }

    currencies {
        id bigint PK
        name string
        code string
        symbol string
        format string
        exchange_rate decimal
        status boolean
        created_at timestamp
        updated_at timestamp
    }

    currency_rates {
        id bigint PK
        currency_id bigint FK
        rate decimal
        date date
        created_at timestamp
        updated_at timestamp
    }
```

## Address System

```mermaid
erDiagram
    addresses }o--o{ addressable : morphed_by
    addresses }|--|| countries : belongs_to

    addresses {
        id bigint PK
        country string
        country_id bigint FK
        street string
        city string
        city_id bigint
        state string
        area_id bigint
        zip string
        addressable_type string
        addressable_id bigint
        created_at timestamp
        updated_at timestamp
    }
```

## Relationships Summary

### User Relationships
- A user can have one user setting
- A user can have many contacts
- A user can have many folders
- A user can have many payment methods
- A user can have many profiles
- A user can have many main items
- A user can have many plans
- A user can have many orders
- A user belongs to a country

### Main Item Relationships
- A main item belongs to a user
- A main item can belong to many categories (stored as JSON)
- A main item belongs to a product
- A main item belongs to a platform
- A main item belongs to a type
- A main item belongs to a folder
- A main item belongs to a payment method
- A main item belongs to a profile
- A main item can have many transactions
- A main item can have many reminders
- A main item can have many pricing plans
- A main item can belong to many profiles
- A main item stores logo and favicon as JSON arrays

### Product Relationships
- A product belongs to a category
- A product belongs to a type
- A product belongs to a platform
- A product can have many main items

### E-commerce Relationships
- A plan can have many user plans
- A plan can have many orders
- A customer belongs to a user
- A customer can have many orders

### System Settings Relationships
- A country can have many timezones
- A country can have many users
- A country can have many addresses
- A language can have many translations
- A currency can have many rates

## Database Schema Evolution

The database schema should evolve to support new features and requirements of the application. Consider documenting major changes here:

1. **User Management**: [Describe improvements to user model]
2. **Main Feature System**: [Describe comprehensive management system]
3. **Product Catalog**: [Describe catalog structure]
4. **E-commerce System**: [Describe e-commerce capabilities]
5. **System Settings**: [Describe system settings structure]

## Conclusion

This document provides a comprehensive visual representation of the database schema using Mermaid diagrams. The diagrams are organized by functional areas to make it easier to understand the relationships between tables. This documentation will be invaluable for developers working on the application, helping them understand the database structure and relationships.

## Notes for AI Agent

When populating this template:
1. Replace generic terms (main_items, folders, etc.) with application-specific terms
2. Update table fields based on actual requirements
3. Ensure relationships accurately reflect the application's data model
4. Add or remove tables as needed for the specific application
5. Update the Relationships Summary section to match the actual schema
6. Document schema evolution specific to the project
7. Consider adding indexes and constraints in the diagram if relevant
