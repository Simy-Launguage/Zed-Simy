# Simy 语法参考

> Simy 是一门面向 **Minecraft 数据包开发** 的 DSL。表层采用现代语言工效学（Rust 风格），
> 底层忠实映射 `scoreboard` / `NBT` / `execute` 的现实，编译目标为 `mcfunction` 与 JSON。
>
> 本文件描述 v0.1 语法规范（已冻结）。

---

## 目录

1. [设计原则](#1-设计原则)
2. [词法](#2-词法)
3. [变量与可变性](#3-变量与可变性)
4. [类型系统](#4-类型系统)
5. [函数](#5-函数)
6. [控制流与作用域](#6-控制流与作用域)
7. [命令与 Minecraft 原子](#7-命令与-minecraft-原子)
8. [变量引用与字符串内插](#8-变量引用与字符串内插)
9. [运算符](#9-运算符)
10. [组件](#10-组件)
11. [语句终止与作用域](#11-语句终止与作用域)
12. [命名约定与生成命名空间](#12-命名约定与生成命名空间)
13. [完整示例](#13-完整示例)
14. [编译映射概览](#14-编译映射概览)

---

## 1. 设计原则

| 原则 | 说明 |
| :--- | :--- |
| **默认不可变，可变显式标记** | 不可变无前缀；可变加 `mut` 前缀，异常情况视觉上“有标记” |
| **减少书写量** | `fn`、条件免括号、`const` 编译期内联 |
| **类型后置** | `name: Type`，可推断时省略 |
| **结构化替代 `execute` 嵌套** | 控制流与作用域块替代原生 `execute` 复杂语法 |
| **贴近 Minecraft 概念** | 实体、方块、物品、计分板、storage 作为一等公民 |

---

## 2. 词法

### 2.1 注释

```simy
// 行注释
/* 块注释 */
/** 文档注释 */
```

### 2.2 标识符

字符集固定为 **ASCII**，且不以数字开头：

```
[A-Za-z_][A-Za-z0-9_]*
```

- **单字符 `_`** 用作**丢弃绑定**（discard binding），语义为“刻意忽略”。
- **`_` 前缀**（如 `_unused`）是允许的，属 **lint 级约定**，不改变语法。

```simy
let _ = compute();        // 丢弃返回值
let _cache = 1;           // lint 约定：标记未使用，语法上仍是普通变量
```

### 2.3 关键字与保留字

**严格保留关键字（15 个）**——不可用作变量名、函数名：

```
let  mut  const  fn  if  else  while  for  in  return  execute  at  component  true  false
```

**上下文识别字**——仅在特定语法位置被当作关键字，其他位置仍是普通标识符：

| 词 | 识别位置 | 其他位置 |
| :--- | :--- | :--- |
| `tick` | 仅 `component { }` 体内（组件方法名） | 命令名（如 `/tick freeze`） |
| `return` | 模块顶层回落为命令；`fn` 体内识别为返回语句 | 命令名（`return run …`） |
| 类型名（见 §4） | 仅在类型位置 | 命令名（如 `/tag`、`/team`、`/item`） |

**透传命令词不保留**——`effect`、`give`、`particle`、`tellraw`、`tp`、`summon`、`data` 等
一律是普通标识符，直接作为命令头使用，无需为每个命令声明关键字。

### 2.4 字面量

| 字面量 | 示例 |
| :--- | :--- |
| 整数 | `42`、`-3` |
| 定点浮点 | `3.14`、`0.5` |
| 布尔 | `true`、`false` |
| 字符串 | `"hello"`、`"连击 x$comboCount!"` |

---

## 3. 变量与可变性

```simy
let damage = 10;                        // 不可变（默认，无前缀）
let mut timer = 0;                      // 可变（mut 前缀，一眼可见）
let target: entity = @e[type=creeper];  // 类型后置，可推断时省略
const MAX_HEALTH = 20;                  // 编译期常量，直接内联，不占计分板
```

**可变性比例策略**：不可变约 80%（配置、中间值），可变约 20%（计时器、游戏状态）。
可变变量必须显式写 `mut`，并声明其存储位置。

**编译层降级**：

| 声明 | 降级 |
| :--- | :--- |
| `const` | 内联消失，不占任何运行时存储 |
| 不可变 `let` | 常量折叠 / SSA 优化 |
| `mut` | `scoreboard` / `storage` |

---

## 4. 类型系统

类型分三层：**基础类型**、**Minecraft 领域类型**（一等公民）、**复合类型**。
所有类型名均**上下文识别、不保留**——它们只在类型位置生效，故 `tag @s add foo;` 等命令不受影响。

### 4.1 基础类型

| 类型 | 说明 | 底层映射 | 字面量示例 |
| :--- | :--- | :--- | :--- |
| `num` | 整数（计分板原生能力） | `scoreboard` (int) | `42`、`-3` |
| `float` | 浮点（编译为定点数，如 ×1000 缩放） | `scoreboard` 缩放 / `storage` NBT | `3.14` |
| `bool` | 布尔，编译为 0/1 | `scoreboard` | `true` / `false` |
| `str` | 字符串 | `storage` NBT / `tellraw` 内联 | `"hello"` |

> `num` 是默认数字类型，因为计分板是整数。`float` 在编译期自动做定点数缩放
> （如乘 1000 存入 scoreboard，再用 `scale=0.001` 换算），用户无感知。

### 4.2 领域类型（一等公民）

| 类型 | 说明 | 底层映射 | 字面量示例 |
| :--- | :--- | :--- | :--- |
| `entity` | 已解析的具体实体（可读属性 `target.health`） | 选择器 / UUID | `@a[distance=..10]` |
| `selector` | 选择器表达式本身（延迟求值） | 原样嵌入命令 | `@e[type=zombie]` |
| `pos` | 坐标（含 `~` 相对坐标） | `storage` 或内联 | `~ ~1 ~`、`(0, 64, 0)` |
| `vec3` | 向量（与 `pos` 配合的运动量） | `storage` | `(0.5, 1.0, -0.2)` |
| `block` | 方块 ID + 方块状态 | 内联 ID | `minecraft:chest[waterlogged=true]` |
| `item` | 物品 ID + NBT / 组件 | 内联 | `minecraft:diamond_sword` |
| `team` | 队伍 | `scoreboard` 原生 | `"adventure"` |
| `tag` | 标签 | `scoreboard` 原生 | `"boss"` |
| `nbt` | 逃生舱：任意原始 NBT | `storage` 原样 | `{Health:10f}` |

> **`entity` vs `selector`**：`entity` 表示“已解析的具体实体”（可读属性、可传参）；
> `selector` 是“选择器表达式本身”（延迟求值，可传入 `execute`）。这个区分让编译器能做更激进的优化。
>
> **`nbt` 逃生舱**：保证 DSL 永远不会被 MC 新版本的新字段卡住——任何无法抽象的东西都能以原始 NBT 传递。

### 4.3 复合类型

| 类型 | 说明 | 底层映射 |
| :--- | :--- | :--- |
| `list<T>` | 列表 | `storage` NBT list |
| `map<k, v>` | 映射（如 `map<str, num>`） | `storage` NBT compound |
| `option<T>` | 可空（配合未来 `?` 传播，“实体可能不存在”） | `scoreboard` 存在位 + 值 |
| 组件实例 | 用户定义的组件类型（见 §10） | `tag` + 多个 `scoreboard` |

### 4.4 类型推断

- `let damage = 10;` 自动推断为 `num`。
- 跨 scoreboard 的值默认 `num`。
- 进 `storage` 的复杂结构需要显式类型注解：

```simy
let scores: map<str, num> = { "kills": 0, "deaths": 0 };
```

---

## 5. 函数

```simy
fn calculate_damage(attacker: entity, victim: entity) -> num {
    let baseDamage = 5;
    let damage = baseDamage * distance_multiplier(victim);
    return damage;
}
```

- 返回类型用 `->` 标注；无返回类型时省略。
- 参数为 `name: Type` 形式，多个参数以 `,` 分隔。
- 函数体是 `{ }` 作用域块。
- **函数名强制 `snake_case`**（见 §12）。

---

## 6. 控制流与作用域

### 6.1 `if` / `else`

条件**免括号**，块以 `{ }` 界定：

```simy
if counter >= 100 {
    tellraw @a "连击达标！";
} else if counter >= 50 {
    tellraw @a "再接再厉";
} else {
    tellraw @a "继续加油";
}
```

> `if`、`for`、`while`、`fn`、`execute`、裸块等**复合语句末尾不需要 `;`**（同 Rust）。

### 6.2 `while`

```simy
while timer > 0 {
    timer -= 1;
}
```

### 6.3 `for … in`（遍历选择器）

```simy
for player in @a[gamemode=adventure] {
    effect give $player minecraft:glowing 1 1;
}
```

### 6.4 `return`

```simy
fn pick(value: num) -> num {
    if value < 0 {
        return 0;
    }
    return value;
}
```

> `return` 是**上下文识别字**：在 `fn` 体内它识别为返回语句；模块顶层回落为普通标识符
> （可调用 `/return run …` 命令）。

### 6.5 `execute` 上下文作用域

用结构化作用域替代原生 `execute` 嵌套。作用域目标写在 `< … >` 中：

```simy
execute at <@a> {
    particle minecraft:heart ~ ~1 ~ 0.5 0.5 0.5 0.1 10;
}
```

- `at <目标>`：切换执行位置。
- 后续可扩展 `as`、`positioned`、`if`、`unless`、`align`、`facing` 等动词。

---

## 7. 命令与 Minecraft 原子

### 7.1 命令语句

命令语句由**命令头**（任意标识符）与**若干结构化原子**组成，以 `;` 结束：

```simy
effect give $player minecraft:glowing 1 1;
tp $player ~ ~1 ~;
tellraw @s "连击 x$comboCount!";
```

- 命令头**不是保留字**，任何标识符都可作命令名（含 `summon`、`effect`、`particle`……）。
- 参数可选的收尾命名参数块：`(key: value, …)`。

```simy
tellraw @s "连击 x$comboCount!" (color: "red");
```

- **区分调用与命令**：`foo(a)` 恒为函数调用；`foo a b` 恒为命令。

```
calc_damage(victim);                  // 函数调用
calc_damage victim;                   // 命令（头 calc_damage + 参数 victim）
```

### 7.2 选择器

```
@a @e @p @r @s @n
```

带参数用 `[ ]`，参数为 `key=value` 或 `key!=value`：

```simy
@a[gamemode=adventure]
@e[type=zombie,distance=..10]
@e[type=creeper,name="Bob"]
@a[tag=boss]
```

### 7.3 坐标与向量

| 形式 | 示例 |
| :--- | :--- |
| 相对坐标 | `~ ~1 ~`、`~-2 ~ ~` |
| 局部坐标 | `^ ^1 ^2` |
| 绝对坐标 | `(0, 64, 0)` |
| 向量 | `(0.5, 1.0, -0.2)` |

### 7.4 命名空间 ID / 方块 / 物品

```simy
minecraft:glowing
minecraft:chest[waterlogged=true]
minecraft:diamond_sword
```

### 7.5 NBT 逃生舱

`{ … }` 中的内容原样透传：

```simy
data merge block ~ ~ ~ { Health:10f };
```

---

## 8. 变量引用与字符串内插

### 8.1 命令上下文：裸引用

以 `$` 引导，靠空白自然截断：

```simy
effect give $player minecraft:glowing 1 1;
tp $player ~ ~1 ~;
```

### 8.2 字符串内插：两种形式

| 形式 | 语法 | 适用场景 |
| :--- | :--- | :--- |
| 短形式 | `$name` | 变量后紧跟标点 / 空白 / 结尾 |
| 花括号 | `${ expr }` | 变量后紧跟 CJK 字符，或需要嵌入任意表达式 |

```simy
tellraw @s "连击 x$comboCount!";          // 短形式：后面是标点，安全
tellraw @s "当前连击：${comboCount}";      // 花括号：后面紧跟 CJK
tellraw @s "总分：${comboCount * 10}";     // 花括号：内含任意表达式
tellraw @s "${a}${b}${c}";                 // 相邻插值，无歧义
```

### 8.3 成员访问

```simy
@s.score += 1;
tellraw @a "HP: ${target.health}";
```

---

## 9. 运算符

由高到低优先级：

| 优先级 | 运算符 | 结合性 |
| :--- | :--- | :--- |
| 1（最高） | `.`（成员访问） | 左 |
| 2 | `()`（调用） | 左 |
| 3 | `!` `-` `+`（一元） | 右 |
| 4 | `*` `/` `%` | 左 |
| 5 | `+` `-` | 左 |
| 6 | `<` `>` `<=` `>=` | 左 |
| 7 | `==` `!=` | 左 |
| 8 | `&&` | 左 |
| 9（最低） | `\|\|` | 左 |

**赋值运算符**：`=` `+=` `-=` `*=` `/=` `%=`

```simy
let damage = base * 2;
@s.score += 1;
timer -= 1;
```

---

## 10. 组件

组件将状态（`scoreboard` / `tag`）与行为（`tick`）打包：

```simy
component Spirit(name: str, effect: str) {
    tick(entity self) {
        effect give $self $effect 1 1;
    }
}

summon Spirit("Speed Spirit", "minecraft:speed");
```

- `component` 名**强制 CamelCase**（见 §12）。
- `tick` 方法名仅在组件体内识别；参数用 `entity self` 形式传入自身。
- 实例化用 `summon`（透传命令词，非关键字），跟随的 `Spirit("…", "…")` 是函数调用。

---

## 11. 语句终止与作用域

| 语句类型 | 结尾 |
| :--- | :--- |
| `let` / `const` / 赋值 / 表达式 / `return` / 命令 | **必须以 `;` 结束** |
| `fn` / `component` / `if` / `for` / `while` / `execute` / 裸 `{ }` 块 | 复合语句，**末尾免 `;`** |

作用域以 `{ }` 界定，嵌套块内声明仅在该块可见。

---

## 12. 命名约定与生成命名空间

> 以下规则 **不改变语法**，由 **lint（转译器前端）** 与 **codegen** 负责强制。

| 对象 | 约定 | 归属 |
| :--- | :--- | :--- |
| 函数名 | 强制 `snake_case` | lint |
| 组件名 | 强制 `CamelCase` | lint |
| 变量名 | 大小写自由 | — |
| 文件路径 | 强制小写 | lint |
| `_` 前缀 | 允许，标记“未使用” | lint |

**生成命名空间**与用户标识符空间**天然隔离**：

| 用途 | 前缀 |
| :--- | :--- |
| 生成的计分板目标 / 内部数据 | `#simy/…` |
| 生成的函数、标签等资源 | `simy:…` |

由于 `#` 与 `simy:` 均不在公开标识符字符集内，用户无法写出同名冲突；
用户手写 `simy:xxx` 会由 lint 报错（保留命名空间）。

---

## 13. 完整示例

```simy
const MAX_HEALTH = 20;

fn distance_multiplier(victim: entity) -> num {
    return 2;
}

fn calculate_damage(attacker: entity, victim: entity) -> num {
    let baseDamage = 5;
    let damage = baseDamage * distance_multiplier(victim);
    return damage;
}

fn tick_handler() {
    if counter >= 100 {
        tellraw @a "连击达标！";
    } else {
        tellraw @a "继续加油";
    }

    for player in @a[gamemode=adventure] {
        effect give $player minecraft:glowing 1 1;
    }

    execute at <@a> {
        particle minecraft:heart ~ ~1 ~ 0.5 0.5 0.5 0.1 10;
    }
}

component Spirit(name: str, effect: str) {
    tick(entity self) {
        effect give $self $effect 1 1;
    }
}

summon Spirit("Speed Spirit", "minecraft:speed");
@s.score += 1;
tellraw @s "连击 x$comboCount!" (color: "red");
tellraw @s "总分：${comboCount * 10}";
```

---

## 14. 编译映射概览

| Simy 构造 | 编译产物 |
| :--- | :--- |
| `const` | 内联，无运行时存储 |
| 不可变 `let` | 常量折叠 / SSA |
| `mut` `let` | `scoreboard` 目标 / `storage` |
| `float` | 定点数缩放（如 ×1000 + `scale=0.001`） |
| `if` / `else` | `execute if …` 分支 |
| `for … in <selector>` | `execute as …` + 迭代 |
| `execute at <x> { }` | `execute at …` |
| 命令语句 | 对应 `mcfunction` 行 |
| `component` | `tag` + 多个 `scoreboard` 目标 |
| 生成物命名 | `#simy/…`、`simy:…` |
