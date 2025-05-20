# Model Relationships Template

This document outlines the relationships between models in the application. Use this template to document how your models relate to each other, which is essential for understanding the application's data flow and structure.

## Core User-Related Relationships

```mermaid
erDiagram
    User ||--o{ Folder : has
    User ||--o{ PaymentMethod : has
    User ||--o{ UserContact : has
    User ||--o{ UserProfile : has
    User ||--o{ MainItem : has
    User ||--o{ Transaction : has
    User ||--o{ Reminder : has
    User ||--o{ UserPlan : has
    User ||--o{ UserTeam : "has as team user"
    User ||--o{ UserTeam : "has as pro user"
    User ||--o{ UserTeam : "has created"
    User ||--o| UserSetting : has
    User ||--o| Customer : has
    User }o--|| Country : "belongs to"
```

## Main Feature Relationships

```mermaid
erDiagram
    MainItem }o--|| User : "belongs to"
    MainItem }o--o| Category : "belongs to"
    MainItem }o--o| Product : "belongs to"
    MainItem }o--o| Platform : "belongs to"
    MainItem }o--o| Type : "belongs to"
    MainItem }o--o| Folder : "belongs to"
    MainItem }o--o| PaymentMethod : "belongs to"
    MainItem }o--o| UserProfile : "belongs to"
    MainItem ||--o{ PricingPlan : has
    MainItem ||--o{ Transaction : has
    MainItem ||--o{ Reminder : has
    MainItem }o--o{ UserProfile : "belongs to many"
```

## Product-Related Relationships

```mermaid
erDiagram
    Product }o--|| Category : "belongs to"
    Product }o--|| Type : "belongs to"
    Product }o--|| Platform : "belongs to"
    Product ||--o{ ProductPricingPlan : has
    Product ||--o{ MainItem : has
```

## E-commerce Relationships

```mermaid
erDiagram
    Customer }o--|| User : "belongs to"
    Customer ||--o{ Order : has
    Order }o--|| Customer : "belongs to"
    Order }o--o| Plan : "belongs to"
    Order ||--o{ Payment : has
    Plan ||--o{ UserPlan : has
    Plan ||--o{ Order : has
```

## Notification-Related Relationships

```mermaid
erDiagram
    UserProfile }o--|| User : "belongs to"
    UserProfile ||--o{ MainItem : has
    UserProfile ||--o{ Reminder : has
    UserProfile }o--o{ MainItem : "belongs to many"
    Reminder }o--|| User : "belongs to"
    Reminder }o--|| UserProfile : "belongs to"
    Reminder }o--|| MainItem : "belongs to"
```

## Other Relationships

```mermaid
erDiagram
    Country ||--o{ CountryTimezone : has
    Country ||--o{ User : has
    UserSetting }o--|| User : "belongs to"
    UserSetting }o--o| UserProfile : "belongs to"
    UserPlan }o--|| User : "belongs to"
    UserPlan }o--|| Plan : "belongs to"
    Transaction }o--|| MainItem : "belongs to"
    Transaction }o--|| User : "belongs to"
    PricingPlan }o--|| MainItem : "belongs to"
    Payment }o--|| Order : "belongs to"
    Address }o--|| "Any Model" : "belongs to"
```

## Notes on Model Naming Conventions

When implementing these relationships in your codebase, follow these naming conventions:
- Use singular, PascalCase names for model classes (e.g., `User`, not `Users`)
- Use camelCase for relationship methods (e.g., `userContacts()`, not `UserContacts()`)
- Use snake_case for database columns (e.g., `user_id`, not `userId`)

## Implementation Examples

### Example: User Model Relationships

```php
class User extends Model
{
    // One-to-Many relationships
    public function folders()
    {
        return $this->hasMany(Folder::class);
    }

    public function paymentMethods()
    {
        return $this->hasMany(PaymentMethod::class);
    }

    // One-to-One relationships
    public function setting()
    {
        return $this->hasOne(UserSetting::class);
    }

    // Belongs-To relationships
    public function country()
    {
        return $this->belongsTo(Country::class);
    }
}
```

### Example: MainItem Model Relationships

```php
class MainItem extends Model
{
    // Belongs-To relationships
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function folder()
    {
        return $this->belongsTo(Folder::class);
    }

    // One-to-Many relationships
    public function transactions()
    {
        return $this->hasMany(Transaction::class);
    }

    // Many-to-Many relationships
    public function profiles()
    {
        return $this->belongsToMany(UserProfile::class, 'profile_item');
    }
}
```

## Notes for AI Agent

When populating this template:
1. Replace generic model names with application-specific names
2. Ensure relationship types (one-to-many, many-to-many, etc.) are correctly represented
3. Update the implementation examples with actual model names and relationships
4. Add any additional relationship diagrams specific to the application
5. Consider adding notes about polymorphic relationships if used
6. Include any special relationship configurations or constraints
