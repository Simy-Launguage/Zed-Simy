# Simy Syntax Reference

**English** | [简体中文](syntax.zh-CN.md)

> Simy is a DSL for **Minecraft datapack development**. It puts modern language
> ergonomics (Rust-like) on the surface while faithfully mapping the reality of
> `scoreboard` / `NBT` / `execute` underneath, compiling to `mcfunction` and JSON.
>
> This document describes the v0.1 grammar (frozen).

---

## Contents

1. [Design principles](#1-design-principles)
2. [Lexical structure](#2-lexical-structure)
3. [Variables and mutability](#3-variables-and-mutability)
4. [Type system](#4-type-system)
5. [Functions](#5-functions)
6. [Control flow and scopes](#6-control-flow-and-scopes)
7. [Commands and Minecraft atoms](#7-commands-and-minecraft-atoms)
8. [Variable references and string interpolation](#8-variable-references-and-string-interpolation)
9. [Operators](#9-operators)
10. [Components](#10-components)
11. [Statement termination and scopes](#11-statement-termination-and-scopes)
12. [Naming conventions and generated namespaces](#12-naming-conventions-and-generated-namespaces)
13. [Complete example](#13-complete-example)
14. [Compilation mapping overview](#14-compilation-mapping-overview)

---

## 1. Design principles

| Principle | Description |
| :--- | :--- |
| **Immutable by default, mutation explicit** | No prefix means immutable; `mut` marks mutability so unusual state is visually flagged |
| **Less ceremony** | `fn`, bracket-free conditions, `const` folded at compile time |
| **Type after name** | `name: Type`, omittable when inferable |
| **Structured instead of nested `execute`** | Control flow and scope blocks replace the native `execute` syntax |
| **Close to Minecraft concepts** | Entities, blocks, items, scoreboards and storage are first-class |

---

## 2. Lexical structure

### 2.1 Comments

```simy
// line comment
/* block comment */
/** documentation comment */
```

### 2.2 Identifiers

The character set is fixed to **ASCII**, and identifiers may not start with a digit:

```
[A-Za-z_][A-Za-z0-9_]*
```

- A **single `_`** is a **discard binding**, meaning "deliberately ignored".
- A **`_` prefix** (e.g. `_unused`) is allowed — a **lint-level convention**, not a
  grammatical feature.

```simy
let _ = compute()        // discard the return value
let _cache = 1           // lint convention: marked unused, still an ordinary variable
```

### 2.3 Keywords and reserved words

**Strictly reserved keywords (15)** — cannot be used as variable or function names:

```
let  mut  const  fn  if  else  while  for  in  return  execute  at  component  true  false
```

**Context-sensitive words** — treated as keywords only in specific positions; elsewhere
they are ordinary identifiers:

| Word | Recognized as a keyword | Elsewhere |
| :--- | :--- | :--- |
| `tick` | Only inside a `component { }` body (method name) | Command name (e.g. `/tick freeze`) |
| `return` | A return statement inside `fn` bodies; falls back to a command at the module top level | Command name (`return run …`) |
| Type names (see §4) | Only in type positions | Command name (e.g. `/tag`, `/team`, `/item`) |

**Passthrough command words are not reserved** — `effect`, `give`, `particle`, `tellraw`,
`tp`, `summon`, `data`, etc. are all ordinary identifiers used directly as a command head.
There is no need to declare a keyword per command.

### 2.4 Literals

| Literal | Examples |
| :--- | :--- |
| Integer | `42`, `-3` |
| Fixed-point float | `3.14`, `0.5` |
| Boolean | `true`, `false` |
| String | `"hello"`, `"combo x$comboCount!"` |

---

## 3. Variables and mutability

```simy
let damage = 10                        // immutable (default, no prefix)
let mut timer = 0                      // mutable (mut prefix, immediately visible)
let target: entity = @e[type=creeper]  // type after name, omittable when inferable
const MAX_HEALTH = 20                  // compile-time constant, inlined, no scoreboard
```

**Mutability ratio strategy**: roughly 80% immutable (configuration, intermediate values)
and 20% mutable (timers, game state). Mutable variables must be marked `mut` explicitly
and declare where they are stored.

**Lowering at compile time**:

| Declaration | Lowering |
| :--- | :--- |
| `const` | Inlined away; occupies no runtime storage |
| Immutable `let` | Constant folding / SSA |
| `mut` | `scoreboard` / `storage` |

---

## 4. Type system

Types come in three layers: **primitive types**, **Minecraft domain types** (first-class)
and **composite types**. All type names are **context-sensitive and not reserved** — they
only take effect in type positions, so commands such as `tag @s add foo` are unaffected.

### 4.1 Primitive types

| Type | Description | Lowering | Literal examples |
| :--- | :--- | :--- | :--- |
| `num` | Integer (scoreboard's native capability) | `scoreboard` (int) | `42`, `-3` |
| `float` | Float (compiled to fixed-point, e.g. ×1000 scaling) | `scoreboard` scaling / `storage` NBT | `3.14` |
| `bool` | Boolean, compiled to 0/1 | `scoreboard` | `true` / `false` |
| `str` | String | `storage` NBT / inlined into `tellraw` | `"hello"` |

> `num` is the default numeric type because scoreboards are integers. `float` is
> automatically scaled to fixed-point at compile time (e.g. multiplied by 1000 to store in
> a scoreboard, then converted back with `scale=0.001`), transparently to the user.

### 4.2 Domain types (first-class)

| Type | Description | Lowering | Literal examples |
| :--- | :--- | :--- | :--- |
| `entity` | A resolved concrete entity (readable properties, e.g. `target.health`) | Selector / UUID | `@a[distance=..10]` |
| `selector` | The selector expression itself (lazily evaluated) | Embedded verbatim into commands | `@e[type=zombie]` |
| `pos` | Position (including `~` relative coordinates) | `storage` or inline | `~ ~1 ~`, `(0, 64, 0)` |
| `vec3` | Vector (motion paired with `pos`) | `storage` | `(0.5, 1.0, -0.2)` |
| `block` | Block ID + block states | Inline ID | `minecraft:chest[waterlogged=true]` |
| `item` | Item ID + NBT / components | Inline | `minecraft:diamond_sword` |
| `team` | Team | Native `scoreboard` | `"adventure"` |
| `tag` | Tag | Native `scoreboard` | `"boss"` |
| `nbt` | Escape hatch: arbitrary raw NBT | `storage`, verbatim | `{Health:10f}` |

> **`entity` vs `selector`**: `entity` is "a resolved concrete entity" (readable
> properties, passable as an argument); `selector` is "the selector expression itself"
> (lazily evaluated, passable into `execute`). This distinction lets the compiler optimize
> more aggressively.
>
> **The `nbt` escape hatch** guarantees the DSL is never blocked by fields added in a new
> Minecraft version — anything not yet abstracted can be passed through as raw NBT.

### 4.3 Composite types

| Type | Description | Lowering |
| :--- | :--- | :--- |
| `list<T>` | List | `storage` NBT list |
| `map<k, v>` | Map (e.g. `map<str, num>`) | `storage` NBT compound |
| `option<T>` | Nullable (pairs with future `?` propagation, "the entity may not exist") | `scoreboard` presence bit + value |
| Component instance | User-defined component type (see §10) | `tag` + several `scoreboard` objectives |

### 4.4 Type inference

- `let damage = 10` is inferred as `num`.
- Values crossing scoreboards default to `num`.
- Complex structures going into `storage` need an explicit type annotation:

```simy
let scores: map<str, num> = { "kills": 0, "deaths": 0 }
```

---

## 5. Functions

```simy
fn calculate_damage(attacker: entity, victim: entity) -> num {
    let baseDamage = 5
    let damage = baseDamage * distance_multiplier(victim)
    return damage
}
```

- The return type is marked with `->`; omit it when there is none.
- Parameters use the `name: Type` form, separated by `,`.
- The body is a `{ }` scope block.
- **Function names are forced to `snake_case`** (see §12).

---

## 6. Control flow and scopes

### 6.1 `if` / `else`

Conditions are **bracket-free**; blocks are delimited by `{ }`:

```simy
if counter >= 100 {
    tellraw @a "combo reached!"
} else if counter >= 50 {
    tellraw @a "keep it up"
} else {
    tellraw @a "keep going"
}
```

> Statements are **terminated by a newline** (Go-style): one statement per line. `if`,
> `for`, `while`, `fn`, `execute` and bare blocks are **compound statements** and need no
> terminator. The `else` keyword and an opening `{` must stay on the same line as what
> precedes them.
>
> Newlines are **ignored inside `()`, `[]`, `<>` and `{}`** (implicit line joining), so
> argument lists, parameter lists and selector arguments can span multiple lines.

### 6.2 `while`

```simy
while timer > 0 {
    timer -= 1
}
```

### 6.3 `for … in` (iterating a selector)

```simy
for player in @a[gamemode=adventure] {
    effect give $player minecraft:glowing 1 1
}
```

### 6.4 `return`

```simy
fn pick(value: num) -> num {
    if value < 0 {
        return 0
    }
    return value
}
```

> `return` is a **context-sensitive word**: inside a `fn` body it is a return statement; at
> the module top level it falls back to an ordinary identifier (so the `/return run …`
> command can be used).

### 6.5 The `execute` context scope

Structured scopes replace native `execute` nesting. The scope target is written between
`< … >`:

```simy
execute at <@a> {
    particle minecraft:heart ~ ~1 ~ 0.5 0.5 0.5 0.1 10
}
```

- `at <target>`: switch the execution position.
- `as`, `positioned`, `if`, `unless`, `align`, `facing` and other verbs can be added later.

---

## 7. Commands and Minecraft atoms

### 7.1 Command statements

A command statement consists of a **command head** (any identifier) and **several
structured atoms**, terminated by a newline:

```simy
effect give $player minecraft:glowing 1 1
tp $player ~ ~1 ~
tellraw @s "combo x$comboCount!"
```

- The command head is **not reserved**; any identifier can be a command name (including
  `summon`, `effect`, `particle`, …).
- Arguments may end with an optional named-argument block: `(key: value, …)`.

```simy
tellraw @s "combo x$comboCount!" (color: "red")
```

- **Calls vs commands**: `foo(a)` is always a function call; `foo a b` is always a command.

```
calc_damage(victim);                  // function call
calc_damage victim;                   // command (head calc_damage + argument victim)
```

### 7.2 Selectors

```
@a @e @p @r @s @n
```

Arguments go in `[ ]` as `key=value` or `key!=value`:

```simy
@a[gamemode=adventure]
@e[type=zombie,distance=..10]
@e[type=creeper,name="Bob"]
@a[tag=boss]
```

### 7.3 Coordinates and vectors

| Form | Examples |
| :--- | :--- |
| Relative coordinates | `~ ~1 ~`, `~-2 ~ ~` |
| Local coordinates | `^ ^1 ^2` |
| Absolute coordinates | `(0, 64, 0)` |
| Vectors | `(0.5, 1.0, -0.2)` |

### 7.4 Namespaced IDs / blocks / items

```simy
minecraft:glowing
minecraft:chest[waterlogged=true]
minecraft:diamond_sword
```

### 7.5 The NBT escape hatch

Whatever is inside `{ … }` is passed through verbatim:

```simy
data merge block ~ ~ ~ { Health:10f }
```

---

## 8. Variable references and string interpolation

### 8.1 Command context: bare references

Introduced by `$`, terminated naturally by whitespace:

```simy
effect give $player minecraft:glowing 1 1
tp $player ~ ~1 ~
```

### 8.2 String interpolation: two forms

| Form | Syntax | When to use |
| :--- | :--- | :--- |
| Short form | `$name` | The variable is followed by punctuation / whitespace / end of string |
| Braced form | `${ expr }` | The variable is immediately followed by a CJK character, or you need to embed an arbitrary expression |

```simy
tellraw @s "combo x$comboCount!"          // short form: followed by punctuation, safe
tellraw @s "current: ${comboCount}"        // braced: immediately followed by CJK
tellraw @s "total: ${comboCount * 10}"     // braced: contains an arbitrary expression
tellraw @s "${a}${b}${c}"                  // adjacent interpolations, unambiguous
```

### 8.3 Member access

```simy
@s.score += 1
tellraw @a "HP: ${target.health}"
```

---

## 9. Operators

From highest to lowest precedence:

| Precedence | Operators | Associativity |
| :--- | :--- | :--- |
| 1 (highest) | `.` (member access) | Left |
| 2 | `()` (call) | Left |
| 3 | `!` `-` `+` (unary) | Right |
| 4 | `*` `/` `%` | Left |
| 5 | `+` `-` | Left |
| 6 | `<` `>` `<=` `>=` | Left |
| 7 | `==` `!=` | Left |
| 8 | `&&` | Left |
| 9 (lowest) | `\|\|` | Left |

**Assignment operators**: `=` `+=` `-=` `*=` `/=` `%=`

```simy
let damage = base * 2
@s.score += 1
timer -= 1
```

---

## 10. Components

A component bundles state (`scoreboard` / `tag`) with behavior (`tick`):

```simy
component Spirit(name: str, effect: str) {
    tick(entity self) {
        effect give $self $effect 1 1
    }
}

summon Spirit("Speed Spirit", "minecraft:speed")
```

- Component names are **forced to CamelCase** (see §12).
- The `tick` method name is recognized only inside a component body; its parameter passes
  `self` using the `entity self` form.
- Instantiation uses `summon` (a passthrough command word, not a keyword); the following
  `Spirit("…", "…")` is a function call.

---

## 11. Statement termination and scopes

| Statement type | Ending |
| :--- | :--- |
| `let` / `const` / assignment / expression / `return` / command | **Terminated by a newline** |
| `fn` / `component` / `if` / `for` / `while` / `execute` / bare `{ }` block | Compound statement, **no terminator** |

Blank lines are allowed between statements, and a line comment never needs a terminator of
its own. Newlines inside `( )`, `[ ]`, `< >` and `{ }` are ignored (implicit line joining),
so lists and arguments can wrap across lines. Scopes are delimited by `{ }`; declarations
inside a nested block are visible only there.

---

## 12. Naming conventions and generated namespaces

> The following rules **do not change the grammar**; they are enforced by **lint (the
> transpiler front end)** and **codegen**.

| Object | Convention | Owner |
| :--- | :--- | :--- |
| Function names | Forced `snake_case` | lint |
| Component names | Forced `CamelCase` | lint |
| Variable names | Any case | — |
| File paths | Forced lowercase | lint |
| `_` prefix | Allowed, marks "unused" | lint |

The **generated namespaces** are **naturally isolated** from the user identifier space:

| Purpose | Prefix |
| :--- | :--- |
| Generated scoreboard objectives / internal data | `#simy/…` |
| Generated functions, tags and other resources | `simy:…` |

Because neither `#` nor `simy:` is in the public identifier character set, users cannot
write a colliding name. A user-written `simy:xxx` is reported by lint as a reserved
namespace.

---

## 13. Complete example

```simy
const MAX_HEALTH = 20

fn distance_multiplier(victim: entity) -> num {
    return 2
}

fn calculate_damage(attacker: entity, victim: entity) -> num {
    let baseDamage = 5
    let damage = baseDamage * distance_multiplier(victim)
    return damage
}

fn tick_handler() {
    if counter >= 100 {
        tellraw @a "combo reached!"
    } else {
        tellraw @a "keep going"
    }

    for player in @a[gamemode=adventure] {
        effect give $player minecraft:glowing 1 1
    }

    execute at <@a> {
        particle minecraft:heart ~ ~1 ~ 0.5 0.5 0.5 0.1 10
    }
}

component Spirit(name: str, effect: str) {
    tick(entity self) {
        effect give $self $effect 1 1
    }
}

summon Spirit("Speed Spirit", "minecraft:speed")
@s.score += 1
tellraw @s "combo x$comboCount!" (color: "red")
tellraw @s "total: ${comboCount * 10}"
```

---

## 14. Compilation mapping overview

| Simy construct | Compiled output |
| :--- | :--- |
| `const` | Inlined; no runtime storage |
| Immutable `let` | Constant folding / SSA |
| `mut` `let` | `scoreboard` objective / `storage` |
| `float` | Fixed-point scaling (e.g. ×1000 + `scale=0.001`) |
| `if` / `else` | `execute if …` branches |
| `for … in <selector>` | `execute as …` + iteration |
| `execute at <x> { }` | `execute at …` |
| Command statement | The corresponding `mcfunction` line |
| `component` | `tag` + several `scoreboard` objectives |
| Generated names | `#simy/…`, `simy:…` |
