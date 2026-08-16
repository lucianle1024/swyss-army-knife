# C / C++ Pointers & References — Cheat Sheet

---

## 1. The Core Idea

A **pointer** is a variable that stores the **memory address** of another variable.

```cpp
int age = 25;      // a normal integer variable
int* ptr = &age;   // 'ptr' holds the memory address of 'age'
```

Two operators make this work:

| Operator | Name | Meaning |
|---|---|---|
| `&x` | Address-of | Gives you the memory address where `x` lives |
| `*p` | Dereference | Follows the address in `p` and reads/writes the value there |

### Mental model — the URL analogy
- A **web page** is the actual content (the data in memory).
- A **URL** is the address of that page (the pointer).
- You don't email 10 pages to share a document — you send the **URL**.
- Opening the link to read/edit the page = **dereferencing (`*p`)**.

### Mental model — coordinates on paper
- **Regular variable** (`int x = 42;`) → a box holding data.
- **Address-of** (`&x`) → the GPS coordinates of that box.
- **Pointer** (`int* p = &x;`) → a slip of paper with those coordinates written on it.
- **Dereference** (`*p`) → following the coordinates to open the box and read/change its contents.

---

## 2. Basic Pointer Usage

```cpp
#include <iostream>

int main() {
    int score = 100;
    int* ptr = &score;              // ptr holds the address of score

    std::cout << score;             // 100
    std::cout << &score;            // e.g. 0x7ffd04
    std::cout << ptr;               // e.g. 0x7ffd04 (same address)
    std::cout << *ptr;              // 100 (reads score through ptr)

    *ptr = 250;                     // modifies score via the pointer
    std::cout << score;             // 250
    return 0;
}
```

| Expression | Meaning |
|---|---|
| `int* p;` | Declares a pointer `p` that points to an `int` |
| `&x` | Gets the memory address of `x` |
| `*p` | Dereferences `p` (accesses the value at that address) |
| `nullptr` | Represents "points to nothing" |

**Safety rules:**
- Always initialize pointers (`int* p = nullptr;` if there's nothing to point to yet).
- Never dereference `nullptr` or an invalid pointer — it causes a segfault.

---

## 3. Reassigning a Pointer

```cpp
int* p = nullptr;   // p holds the null address, points to nothing yet

int number = 42;
p = &number;         // p now holds the address of number

std::cout << *p;     // 42
*p = 100;             // modifies 'number' directly
```

Two very different operations:

- **`p = &number;`** → changes **where** `p` points (rebinds the address stored in `p`).
- **`*p = 100;`** → changes the **value** at the address `p` currently points to.

> Dereferencing a `nullptr` (`*p = 10` while `p == nullptr`) crashes — always point somewhere valid first.

### The one exception: constant pointers
```cpp
int* const p = nullptr; // p itself is constant — locked to this address forever
p = &number;             // compiler error: assignment of read-only variable 'p'
```

---

## 4. When You Don't Need `&`

`&` is only needed when converting a **value variable** into an address. If the right-hand side is *already* an address, skip it.

| Source | What it already is | Example |
|---|---|---|
| Regular variable | A value | `int* p = &x;` ← needs `&` |
| Array name | Address of first element (decays) | `int* p = numbers;` |
| String literal | Address of first char | `const char* str = "Hello";` |
| `new` / `malloc` | Heap address | `int* p = new int(42);` |
| Existing pointer | Already an address | `int* p2 = p1;` |
| Function returning a pointer | Already an address | `int* r = findElement(...);` |

```cpp
int numbers[5] = {10, 20, 30, 40, 50};
int* p = numbers;              // no '&' — array name already decays to &numbers[0]

int a = 10;
int* p1 = &a;                  // needs '&' — 'a' is a plain value
int* p2 = p1;                  // no '&' — p1 already holds an address
```

---

## 5. Pointers in Functions

By default, C/C++ pass arguments **by copy**. Passing a pointer lets a function modify the caller's original variable:

```cpp
void doubleValue(int* numPtr) {
    if (numPtr != nullptr) {
        *numPtr = (*numPtr) * 2;   // updates the original memory
    }
}

int main() {
    int val = 15;
    doubleValue(&val);
    std::cout << val;             // 30
}
```

---

## 6. Dynamic Memory (Heap Allocation)

```cpp
int* dynamicNum = new int(42);   // allocate on the heap
std::cout << *dynamicNum;

delete dynamicNum;                // free it — required, or it leaks
dynamicNum = nullptr;             // avoid a dangling pointer
```

- Forgetting `delete` → **memory leak**.
- Using memory after `delete` → **use-after-free** (undefined behavior).
- `delete`-ing twice → **double free**.

---

## 7. References

A **reference** is an **alias** — another name for an existing object. C++ only (no references in C).

```cpp
int x = 10;
int y = 20;

int& ref = x;     // 'ref' is an alias for 'x' — no separate memory of its own
ref = 15;         // modifies x directly, no '*' needed
ref = y;          // copies y's VALUE (20) into x — does NOT rebind ref to y!
```

Key trap: assigning to a reference **never re-targets it** — it just writes through to whatever it's already bound to.

---

## 8. Pointer vs. Reference

| Feature | Pointer (`int* ptr`) | Reference (`int& ref`) |
|---|---|---|
| Mental model | A URL / address to data | An alias / nickname |
| Nullability | Can be `nullptr` | **Cannot** be null — must bind to a real object |
| Reassignment | Can be re-pointed anytime | **Cannot be rebound** — fixed for life once created |
| Initialization | Can be left uninitialized | **Must** be initialized at declaration |
| Syntax | `*ptr` to read/write, `&var` to bind | Plain variable syntax, no `*` needed |
| Arithmetic | Supports `ptr++`, `ptr + 4` | No arithmetic |
| Language | C and C++ | C++ only |

```cpp
int x = 10, y = 20;

// -- REFERENCE --
int& ref = x;      // alias for x
ref = 15;           // modifies x directly
ref = y;             // copies y's value into x — does NOT rebind

// -- POINTER --
int* ptr = &x;      // holds address of x
*ptr = 30;            // dereferencing modifies x
ptr = &y;              // rebinds ptr to y
*ptr = 40;              // modifies y
```

### Pointer vs. reference as a function parameter

```cpp
// Pointer: must check for nullptr, caller must pass &val
void addFive(int* p) {
    if (p != nullptr) *p += 5;
}

// Reference: guaranteed valid, caller just passes val
void addFive(int& r) {
    r += 5;
}

addFive(&num);   // pointer call
addFive(num);    // reference call — cleaner, no null risk
```

### Rule of thumb
**Default to references** (`Type&` / `const Type&`):
- Function parameters to avoid copies (`const std::string&`)
- Modifying an argument without null checks or `&`/`*` syntax
- Operator overloading (`operator[]`, `operator<<`)

**Use pointers only when:**
- The value is genuinely **optional** — `nullptr` is a meaningful "no value"
- You need to **rebind** to a different object over time
- You're doing **pointer arithmetic** or working with raw C-style arrays/buffers
- Building **dynamic structures** (linked lists, trees) or using smart pointers (`std::unique_ptr`)

---

## 9. Reading `Type& name` / `&variable` / `Type* name` / `*pointer`

`&` and `*` mean different things depending on whether they appear in a **declaration** or as an **operator on an existing variable**.

| Syntax | Context | Meaning | Plain English |
|---|---|---|---|
| `Type* name` | Declaration | Creates a **pointer** | "Make a variable that stores an address." |
| `Type& name` | Declaration | Creates a **reference** | "Make an alias for an existing object." |
| `&variable` | Expression | **Address-of** operator | "Give me the address of `variable`." |
| `*pointer` | Expression | **Dereference** operator | "Go to the address in `pointer` and read/write what's there." |

**Quick trick:**
- Next to a **type** (`int*`, `int&`) → you're declaring what *kind* of variable it is.
- Next to a **variable** (`*p`, `&x`) → you're performing an *action*.

```cpp
int original = 100;

int* ptr = &original;   // Type*  ...  &variable  → ptr stores the address of original
int& ref = original;    // Type&                   → ref is an alias for original

*ptr = 200;              // *pointer → modifies original through ptr
ref = 300;                // (no symbol needed — ref already IS original) → modifies original

std::cout << original;   // 300
std::cout << *ptr;        // 300
std::cout << ref;          // 300
std::cout << &original;    // e.g. 0x7ffd04
std::cout << ptr;           // e.g. 0x7ffd04 (same address)
std::cout << &ref;           // e.g. 0x7ffd04 (address of the aliased object)
```

---

## 10. When to Use Pointers/References — 5 Scenarios

1. **Modifying the original in a function (pass-by-reference)** — default is pass-by-copy; use a pointer/reference to act on the caller's actual variable.
2. **Avoiding expensive copies** — passing a large struct/object copies it in full; passing a pointer/reference only passes an 8-byte address.
3. **Dynamic memory & lifetime** — data whose size isn't known until runtime, or that must outlive the function that created it, needs heap allocation (`new`/`malloc`), which returns a pointer.
4. **Dynamic data structures** — linked lists, trees, graphs need pointers so nodes can link to other nodes.
5. **Optional / nullable values** — a pointer can be `nullptr` to represent "no value" (e.g. a lookup function that may not find anything).

---

## 11. Decision Table — Value vs. Reference vs. Pointer

| Data Type / Scenario | Recommended | Example Signature | Why |
|---|---|---|---|
| Primitives (`int`, `float`, `char`, `bool`, `enum`) | **Value (copy)** | `void fn(int x)` | ≤8 bytes; register copy is cheaper than indirection |
| Small structs (≤16 bytes, e.g. `Point2D{x,y}`) | **Value (copy)** | `void fn(Point2D pt)` | Fits in 1–2 CPU registers, no pointer overhead |
| Standard containers (`std::string`, `std::vector`, `std::map`) | **`const` reference** | `void fn(const std::string& s)` | Avoids deep heap copy |
| Large structs / classes | **`const` reference** | `void fn(const BigStruct& data)` | Passes an 8-byte reference instead of copying hundreds/thousands of bytes |
| Out / in-out parameters (must modify caller's variable) | **Reference** | `void fn(int& val)` | Clean syntax, guaranteed non-null, no `*`/`&` needed at call site |
| Optional / nullable arguments | **Pointer** | `void fn(const Config* cfg)` | `nullptr` can mean "no value passed" (or use `std::optional<T>`) |
| Polymorphic base classes | **Reference or pointer** | `void fn(Base& b)` / `void fn(Base* b)` | Avoids **object slicing** from copying a derived type into a base |
| Node links in dynamic structures (linked lists, trees, graphs) | **Pointer** | `Node* next;` | Needs rebinding, dynamic lifetime, null-termination |
| Lightweight array views (`std::string_view`, `std::span`) | **Value (copy)** | `void fn(std::string_view sv)` | Already a fat pointer (pointer + size); copying is trivial |

**Quick decision flow:**
- Size ≤16 bytes, primitive/small value type → **copy**
- Read-only large object/container → **`const Type&`**
- Must modify caller's data → **`Type&`**
- Nullable / optional / needs rebinding → **`Type*`** (or a smart pointer)

---

## 12. Modern C++: Prefer References & Smart Pointers

Avoid raw owning pointers where possible — they're a common source of leaks and dangling pointers.

| Use Case | Old / C Way | Modern C++ Best Practice |
|---|---|---|
| Modifying function arguments | Raw pointer (`void foo(int* x)`) | **Reference** (`void foo(int& x)`) |
| Passing large read-only objects | `const Type*` | **`const Type&`** |
| Dynamic, single-owner heap data | `new` / `delete` | **`std::unique_ptr`** |
| Dynamic, shared heap data | Manual ref-counting | **`std::shared_ptr`** |
| Array of dynamic items | Raw pointer / `malloc` | **`std::vector`** |

**Summary:**
1. Default to **`const Type&`** for input parameters of non-primitive types.
2. Default to **`Type&`** when a function must modify an existing argument.
3. Use raw pointers (`Type*`) mainly as **non-owning, optional observers** — always check `!= nullptr` before dereferencing.
4. Avoid owning raw pointers (`new`/`delete`) in modern code — prefer `std::vector`, `std::unique_ptr`, `std::shared_ptr`.
