# C3 Modern Style Guide

> A practical reference for writing clean, idiomatic, and optimized C3 code — based on the official **C3 Naming Rules** and community best practices.

---

## Table of Contents

1. [Naming Conventions](#naming-conventions)
2. [Functions](#functions)
3. [Methods](#methods)
4. [Structs & Unions](#structs--unions)
5. [Enums & Faults](#enums--faults)
6. [Variables & Constants](#variables--constants)
7. [Modules](#modules)
8. [Error Handling with Optionals](#error-handling-with-optionals)
9. [Contracts](#contracts)
10. [Defer](#defer)
11. [Generics](#generics)
12. [Comments](#comments)
13. [General Formatting Rules](#general-formatting-rules)

---

## Naming Conventions

C3 enforces rigid naming rules so that tools can parse code unambiguously. Identifiers are limited to `a–z`, `A–Z`, `0–9`, and `_`. The first character cannot be a digit. Max length: 127 characters.

| Construct | Style | Example                       |
|---|---|-------------------------------|
| Types (struct, enum, typedef) | `PascalCase` | `PlayerState`, `HttpRequest`  |
| Variables & parameters | `camelCase` | `playerHp`, `maxSize`         |
| Global constants | `UPPER_SNAKE_CASE` | `MAX_BUFFER_SIZE`, `PI`       |
| Enum members / Faults | `UPPER_SNAKE_CASE` | `COLOR_RED`, `FILE_NOT_FOUND` |
| Struct / union members | `camelCase` | `hitPoints`, `isAlive`        |
| Functions & macros | `camelCase` | `calculateDamage`, `coerceIn` |
| Modules | `lowercase` (no uppercase) | `game::physics`, `net::http`  |

### ✅ Valid vs ❌ Invalid

```c3
// Types
PlayerState  ✅      // PascalCase
playerState  ❌      // must start uppercase
PLAYER_STATE ❌      // all-caps not allowed for types
player_state ❌      // lowercase not allowed for types

// Functions
fn void updatePlayer() ✅
fn void update_player()  ❌
fn void UpdatePlayer()  ❌   // must start lowercase
fn void update-player() ❌   // hyphens not allowed

// Global constants
const int MAX_HEALTH = 100;  ✅
const int maxHealth  = 100;  ❌   // must start uppercase
```

---

## Functions

### Basic Declaration

```c3
// Standard form
fn float add(float x, float y) {
    return x + y;
}
```

### Short (Arrow) Syntax

Use `=>` when the body is a single expression. This is the preferred idiomatic style for simple functions.

```c3
// ✅ Preferred for single-expression functions
fn float add(float x, float y) => x + y;
fn int square(int n) => n * n;
fn bool isEven(int n) => n % 2 == 0;
fn float lerp(float a, float b, float t) => a + (b - a) * t;
```

Do **not** use `=>` for multi-step logic — use the block form instead.

```c3
// ❌ Awkward: don't squeeze multi-step logic into arrow syntax
fn int clamp(int val, int lo, int hi) => val < lo ? lo : val > hi ? hi : val;

// ✅ Better: block form for non-trivial logic
fn int clamp(int val, int lo, int hi) {
    if (val < lo) return lo;
    if (val > hi) return hi;
    
    return val;
}
```

### Named Arguments

```c3
fn void setColor(int red, int green, int blue) { ... }

// Caller can name arguments for clarity
setColor(red: 255, green: 0, blue: 128);
```

### Variadic Functions

```c3
fn void log(String fmt, args...) { ... }
```

---

## Methods

Associate functions with a type using `TypeName.method_name`. The first parameter is the receiver (conventionally named `self`).

```c3
struct Vec2 { 
    float x;
    float y;
}

// Method — takes a pointer receiver for mutation
fn void Vec2.scale(Vec2* self, float factor) {
    self.x *= factor;
    self.y *= factor;
}

// Short form for read-only computed property
fn float Vec2.length(Vec2 self) => math::sqrt(self.x * self.x + self.y * self.y);

// Call with dot syntax
Vec2 v = { 3.0, 4.0 };
v.scale(2.0);
float len = v.length();   // 10.0
```

Use a **pointer receiver** (`TypeName*`) when the method mutates the struct.
Use a **value receiver** (`TypeName`) for read-only queries and computations.

---

## Structs & Unions

```c3
// ✅ PascalCase type, camelCase members
struct Player {
    String name;
    int hitPoints;
    float speed;
    bool isAlive;
}

// Designated initializer
Player p = { 
    .name = "Hero", 
    .hitPoints = 100, 
    .speed = 5.0, 
    .isAlive = true 
};

// ❌ Avoid unnamed positional init for structs with many fields
Player p = { "Hero", 100, 5.0, true };  // hard to read
```

---

## Enums & Faults

```c3
// Enum — UPPER_SNAKE_CASE members
enum Direction {
    NORTH,
    SOUTH,
    EAST,
    WEST
}

// Fault — used with optionals for error handling
fault FileError {
    NOT_FOUND,
    PERMISSION_DENIED,
    IO_ERROR
}

// Reference enum values by qualified name
Direction dir = Direction.NORTH;
```

---

## Variables & Constants

```c3
// Local variables — camelCase
int maxRetries = 3;
float deltaTime = 0.016;
bool isRunning = true;

// Global constants — UPPER_SNAKE_CASE
const int MAX_PLAYERS = 8;
const float GRAVITY = 9.81;
const String DEFAULT_HOST = "localhost";

// Inferred type — use when the type is obvious
var count = 0;           // int
var name = "Alice";     // String
```

Prefer explicit types for function parameters and struct members. Use `var` only for local variables where the type is unambiguous from the right-hand side.

---

## Modules

Module names are all **lowercase**, using `_` as a separator if needed. Sub-paths use `::`.

```c3
// File: src/net/http.c3
module net::http;

fn String? get(String url) { ... }
```

```c3
// Using another module
import net::http;

fn void main() {
    String? body = http::get("https://example.com");
}
```

Guidelines:
- One module per file is the recommended pattern.
- Keep module names short and descriptive: `audio`, `math`, `game::physics`.
- Avoid deep nesting beyond two levels: `engine::render` is fine; `engine::render::pipeline::pass::depth` is not.

---

## Error Handling with Optionals

C3 uses `?` suffix for optional return types — a value that may be a fault instead of a result.

```c3
// Returns int or a fault
fn int? parseInt(String s) { ... }

// ✅ Propagate with `!` (rethrow on fault)
fn int? doubleParse(String s) => parseInt(s)! * 2;

// ✅ Handle explicitly with if-catch
fn void try_parse(String s) {
    int? result = parseInt(s);
    
    if (catch err = result) {
        io::printfn("Error: %s", err);
        return;
    }
    
    io::printfn("Value: %d", result);
}

// ✅ Provide a default with ?? 
int value = parseInt(input) ?? 0;
```

Do **not** return sentinel values like `-1` or `null` to signal errors — use faults.

```c3
// ❌ C-style error signaling
fn int parseInt(String s) { return -1; }  // What does -1 mean?

// ✅ C3 idiomatic
fn int? parseInt(String s) { ... }        // fault carries the reason
```

---

## Contracts

Use `@require` and `@ensure` to express preconditions and postconditions directly on functions. They are checked at compile time or in debug builds.

```c3
fn float sqrt_safe(float x)
    @require(x >= 0.0, "Input must be non-negative")
    @ensure(return >= 0.0) 
{
    return math::sqrt(x);
}

fn void set_health(Player* p, int hp)
    @require(hp >= 0 && hp <= MAX_HEALTH)
    @require(p != null) 
{
    p.hitPoints = hp;
}
```

Contracts document intent and catch bugs early — prefer them over defensive `if` checks at the top of a function.

---

## Defer

`defer` runs a statement when the current scope exits, regardless of how it exits.

```c3
fn void process_file(String path) {
    File! f = file::open(path, "r")!;
    defer f.close();   // always runs, even on early return

    // ... process file ...
}
```

```c3
// defer runs in reverse order (LIFO)
fn void example() {
    defer io::println("third");
    defer io::println("second");
    defer io::println("first");
    // Output: first, second, third
}
```

Use `defer` for all resource cleanup. Avoid manual cleanup at every return path.

---

## Generics

C3 generics use `(<Type>)` syntax on modules.

```c3
// Generic stack in module stack.c3
module stack(<Type>);

struct Stack {
    Type[] data;
    int top;
}

fn void Stack.push(Stack* self, Type val) { ... }
fn Type Stack.pop(Stack* self) { ... }
```

```c3
// Instantiate with a concrete type
import stack(<int>);

Stack(<int>) intStack;
intStack.push(42);
```

---

## Comments

```c3
// Single-line comment

/*
 * Block comment for multi-line explanations.
 * Use sparingly — prefer clear naming over comments.
 */

/**
 * Doc comment for public API functions.
 * @param x The first operand.
 * @param y The second operand.
 * @return The sum of x and y.
 */
fn float add(float x, float y) => x + y;
```

Comment **why**, not **what**. Code should read clearly enough to explain what it does.

```c3
// ❌ Useless comment
// Increment i by 1
i++;

// ✅ Useful comment
// Skip the null terminator at the end of the buffer
i++;
```

---

## General Formatting Rules

### Braces

C3's recommended style places the opening brace on the **same line** (K&R style), consistent with the official docs and examples.

```c3
// ✅ Official C3 style
fn void update(Player* p) {
    if (p.isAlive) p.hitPoints -= 10;
}

// ❌ Allman style — valid but inconsistent with official style
fn void update(Player* p)  
{
    if (p.isAlive) 
    {
        p.hitPoints -= 10;
    }
}
```

### Indentation & Spacing

```c3
// 4 spaces per indent level (no tabs)
fn void example() {
    int x = 1;
    if (x > 0) x += 1;
}

// Spaces around binary operators
float result = a + b * c;
bool check = (x >= 0) && (x < MAX);

// No space before function call parentheses
int n = square(5);   ✅
int n = square (5);  ❌
```

### Line Length & Alignment

Keep lines under **100 characters**. Align related declarations vertically for readability when declaring multiple items together.

```c3
// ✅ Aligned declarations
const int MAX_WIDTH = 1920;
const int MAX_HEIGHT = 1080;
const float ASPECT = 16.0 / 9.0;
```

### One Statement Per Line

```c3
// ❌ Never put multiple statements on one line
int x = 0; int y = 0; int z = 0;

// ✅
int x = 0;
int y = 0;
int z = 0;
```

---

## Quick-Reference Cheatsheet

```c3
// Types
struct PlayerState { ... }          // PascalCase
enum Direction { NORTH, ... }       // UPPER_SNAKE_CASE members
fault IoError { NOT_FOUND }         // UPPER_SNAKE_CASE members

// Functions
fn float add(float x, float y) => x + y;          // arrow — simple
fn int clamp(int v, int lo, int hi) { ... }       // block — complex
fn int? parse(String s) { ... }                    // optional return

// Variables
int count = 0;           // local — camelCase
const int MAX = 100;         // global constant — UPPER_SNAKE_CASE
var name = "Alice";     // inferred local

// Error handling
int value = parse(s) ?? 0;      // default fallback
int v = parse(s)!;              // propagate fault
if (catch err = parse(s)) { }   // explicit handling

// Contracts
fn void set(int x) @require(x >= 0) { ... }

// Defer
defer resource.free();          // cleanup on scope exit

// Methods
fn float Vec2.length(Vec2 self) => math::sqrt(self.x * self.x + self.y * self.y);
```
