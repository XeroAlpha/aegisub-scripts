# ProjectXero's Aegisub scripts

本仓库用于放一些我常用的 [Aegisub](https://github.com/Ristellise/AegisubDC) 脚本，旨在快速开发特效，缩短开发时间。基于 BSD 3-Clause 协议开源。

## autoload/ln.kara-templater-mod.lua

这是一个修改过的卡拉OK模板脚本，放置于 `autoload` 目录下自动加载即可。

原仓库：[logarrhythmic/karaOK](https://github.com/logarrhythmic/karaOK)。

我在 logarrhythmic 修改版本的基础上增加了部分函数。

### load_fx(effect)

寻找第一个包含 `fx <effect>` 的模板行，为其创建解释器 `run(extra)` 并返回。

通过此函数可以方便地复用模板行，使得模板行中可以插入其他模板行，以便于统一修改参数。

此外支持通过内联变量自定义参数，将内联变量构成的表传入解释器的 `extra` 参数即可。

推荐只在需要多次使用自定义参数的场景下使用此函数，其他情况使用 `use_fx` 函数替代。

- 例子：复用淡入淡出特效
```
template line fx a: {\fad(100,100)}
code once: fade_tag = load_fx("a");
template line: !fade_tag()!{\pos(100,100)}
[result]: {\fad(100,100)}{\pos(100,100)}
```

- 例子：复用淡入淡出特效，支持自定义时长
```
template line fx b: {\fad($time,$time)}
code once: fade_tag_var = load_fx("b");
template line: !fade_tag_var({time=150})!{\pos(100,100)}
[result]: {\fad(150,150)}{\pos(100,100)}
```

### use_fx(effect[, extra])

寻找包含 `fx <effect>` 的模板行，并在当前作用域下解释模板。

无需指定自定义参数的情况下 `extra` 可省略。等效于带缓存的 `load_fx(effect)(extra)`。

- 例子：复用文字与边界透明度配置，支持配置透明度
```
template line fx c: {\1a$alphaa\3a$alphac}
template line: !use_fx("c",{alphaa="&HFF&",alphac="&H00&"})!{\pos(100,100)}
[result]: {\1a&HFF&\3a&HFF&}{\pos(100,100)}
```

### t(str)

为行内模板创建解释器。解释器是一个函数，在调用时会解释模板并返回结果。

行内模板与普通模板行类似，但 `$` 被替换为 `@`，`!` 被替换为 <code>&#96;</code>。 

- 例子：定义行内模板以便复用
```
code once: pos = t"\\pos(@x,@y)"
template line: {!pos()!}
```

- 例子：执行行内模板并返回
```
template line: {!t"\\pos(`locate()`)"()!}
```

### use_tag(source, id[, index])

获取 `source` 所在的文本中 ASS 标签 `<id>` 的值。支持自定义标签。

`index` 参数用于获得 ASS 标签的第 `<index>` 个参数。

当 `source` 为 `line`（当前行）时，可省略为 `u(id, index)` 或者 `u[id](index)`。

当 `source` 为 `syl`（当前音节）时，可省略为 `usyl(id, index)` 或者 `usyl[id](index)`。

- 例子：继承原始行的部分特效标签
```
{\1a&H80&\fad(100,0)}Test line
template line: {\1c&HFFFFFF&\1a!u("1a")!\fad(!u.fad(1)!,!u.fad(2)!)}
[result]: {\1c&HFFFFFF&\1a&H80&\fad(100,0)}Test line
```

- 例子：使用自定义标签向模板行传递参数
```
{\color&HFF0000&}Test line 1
{\color&H00FF00&}Test line 2
template line: {\1c!u.color()!\fad(100,100)}
[result]: {\1c&HFF0000&\fad(100,100)}Test line 1
[result]: {\1c&H00FF00&\fad(100,100)}Test line 2
```

### locate(ox, oy, x, y, align)

将 `ox,oy` 指定的坐标转换到由 `x,y,align` 指定的坐标系，返回逗号分隔的坐标字符串。

所有参数均可省略。`ox,oy` 默认为原中心点，`x,y` 默认为通过 `pos` 标签指定的坐标，`align` 默认为 `an` 标签指定的对齐方式或样式指定的对齐方式。

变体 `locate_c(ox, oy, x, y, align)` 返回 `x, y` 两个值。

变体 `locate_s(ox, oy, x, y, align)` 返回空格分隔的坐标字符串。

- 例子：逐字模板位置设定
```
{\pos(100,100)}Test line
template char: {\pos(!locate()!)}
```

### define(name, value[, var_type])

在内联变量中定义新变量，或修改已有变量的值。变量名只能包含**小写字母与下划线**。

可以通过 `var_type` 来指定变量的类型。`template` 会将 `value` 字符串作为模板处理。`computed` 会在每次调用变量时执行 `value` 函数并返回它的结果。

已定义的内联变量可通过 `varctx` 表来访问，但 `use_fx` 与 `load_fx` 的自定义参数除外。

自动生成的内联变量会覆盖使用此函数定义的内联变量。

- 例子：通过内联变量修改参数
```
code once: define("myvar", 1.2);
template line: {\frz$myvar}
```

- 例子：定义模板变量方便复用（`pos1` 与 `pos2` 变量作用相同）
```
code once: define("pos1", "\\pos($x, $y)", "template");
code once: define("pos2", t"\\pos(@x, @y)", "computed");
```

### transform(t1, t2, step, tag, easing)

通过大量 `\t(...)` 标签拟合有复杂曲线的特效标签。

此处的“曲线”是指特效标签从起始状态到结束状态的进度 `x` 随时间进度 `p` （介于 0 到 1 之间）变化的曲线。`\t` 自带的 `accel` 参数使用幂函数曲线（`x = p ^ accel`）。

在 `t1` 与 `t2` 间按 `step` 指定的步长对 `easing` 指定的曲线进行幂函数拟合，并根据拟合曲线的各段与 `tag` 函数返回的标签生成 `\t(...)` 标签。

`t1`、`t2` 为 `nil` 时使用当前行的开头与结尾作为拟合时间区间。`step` 为 `nil` 时使用一帧时长的一半作为步长。

可以通过向 `tag` 参数传入一个行内模板来定义生成标签的内容。行内模板支持以下自定义内联变量（无法通过 `varctx` 访问）。

内联变量 `p` 表示当前进度（即上文中提到的 `x`）。

内联变量 `t` 表示当前拟合到的时间点距离开始时间的毫秒数。

内联变量 `tstart` 与 `tend` 表示拟合的时间区间（即 `t1` 与 `t2`）。

也可以向 `tag` 传入一个返回字符串的函数 `function(p, t, t1, t2)` 来实现更复杂的标签生成。

`easing` 参数表示一个拟合曲线。如果没有指定，则默认使用 `x = p`。可以传入一个函数 `function(p, t, t1, t2)` ，其中 `p` 为时间进度，除此以外其他与 `tag` 的函数参数一致。函数的返回值将作为当前进度（`x`）传递给 `tag` 。

- 例子：文字从 90° 旋转至 0° 后在惯性下继续旋转后回正。（使用了 [`easeOutBack`](https://easings.net/#easeOutBack) 曲线）
```
code once:
function ease_out_back(c1)
    local c3 = c1 + 1;
    return function(x)
        return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2);
    end
end
template line: {!transform(0, 300, 10, "\\frz`90*(@p-1)`", ease_out_back(1.7))!} 
```

- 例子：文字来回左右摇晃
```
code once:
function swing(interval, w)
    return function(x, t)
        return math.sin((w / 180 + t / interval * 2) * math.pi);
    end
end
template line: {!transform(nil, nil, 10, "\\frz`@p*3`", swing(800, random(0,360)))!\}
```

### random(...)

返回随机数。`math.random` 的别名。

随机种子在每次应用模板前都会被设置为固定值。

如果需要每次随机种子都不同，可以手动在 `code once` 模板行中设置随机种子为系统时间。
```
code once: import("os"); math.randomseed(os.time());
```

### log([level,] msg, ...)

输出日志。`_G.aegisub.log` 和 `_G.aegisub.debug.out` 的别名。

当仅传入一个参数时会将此参数转为字符串输出。

- 例子：向日志输出分辨率大小
```
code once: log("%d*%d", meta.res_x, meta.res_y);
```

### import(name[, alias])

将指定的脚本模块导入到全局作用域。

等效于 `tenv[alias or name] = require(name)`。

- 例子：导入 Yutils 库
```
code once: import("Yutils"); log(Yutils ~= nil);
```

- 例子：导入 karaOK 库
```
code once: import("ln.kara", "kara"); log(kara ~= nil);
```

### import_local(path[, name])

读取并在全局作用域下执行指定位置的脚本文件，并将结果保存到全局作用域。

此函数不会对返回结果进行缓存，推荐仅在 `code once` 模板行中使用。

在脚本文件的全局作用域中定义的函数、变量等可在之后的模板行中使用。

- 例子：在全局作用域下执行字幕文件同一目录下的 `a.lua` 文件。
```
code once: import_local("?script/a.lua");
```

### styles(name)

返回指定名称样式对象的副本。如果不存在指定的样式则返回 `nil`。

### makeloop(receiver, ...)

通过内置单层循环模拟多层循环。

参数 `receiver` 接收函数或字符串作为参数。当接收函数时，表示循环变量状态表作为参数传入函数，并返回函数的返回结果。当接收字符串时，循环变量状态表会被存储至全局作用域的指定变量下。

后续参数可以概括为 `{ name1, range1, name2, range2, ... }`。其中 `name` 是循环变量的名称，**每个模板行唯一**。`range` 是用数值 `end` 或表 `{ start, end[, step] }` 表示的范围，计数默认从 1 开始，以 1 为单位步进。

循环时最先指定的循环变量在最内层，变化的速度最快。

此函数可以在同一模板行内被多次调用。在 `use_fx` 或 `load_fx` 函数中的调用视为在顶层调用者模板行中的调用。

此函数与 `loopctl` 或 `maxloop` 不兼容。`makeloop` 本身依靠内置的 `j` 循环实现功能，更改循环次数 `maxj` 或循环变量 `j` 会造成不可知的后果。如果使用 `repeat` 等方式实现循环，也无法从 `j` 变量中读取到正确的循环次数。

此函数会在调用时检测 `j` 的值，如果为 1 时会根据给定的 `range` 参数对循环数据进行初始化，为其他值时忽略 `range` 参数。之后每次调用时，此函数会根据之前初始化的循环数据从 `j` 的值中提取出不同循环变量的状态，并传递给 `receiver`。

- 例子：在 X 与 Y 方向各循环五次，共生成 25 行
```
template line: !makeloop("loop", "x", 5, "y", 5)!{\pos(!$x+loop.x*50!,!$y+loop.y*50!)}
```

- 例子：同上，但对齐方式居中，生成的方阵也居中
```
template line: {\pos(!makeloop(t"@x,@y", "x", { $x - 100, $x + 100, 50 }, "y", { $y - 100, $y + 100, 50 })!)}
```

### loopset(...)

设置由 `makeloop` 定义的循环变量的值。

后续参数可以概括为 `{ name1, value1, name2, value2, ... }`。其中 `name` 是循环变量的名称。`value` 是循环变量的值。

- 例子：同上，但 X 与 Y 同步变化
```
template line: !makeloop("loop", "x", 5)!!makeloop("loop", "y", 5)!{\pos(!$x+loop.x*50!,!$y+loop.y*50!)}!loopset("y", loop.x + 1)!
```

### perframe(receiver)

一个用于实现逐帧特效的快捷函数。

相当于 `makeloop(receiver, "absframe", { start_frame, end_frame - 1 })` 与 `retime("line", absframe, absframe + 1)`。

当 `receiver` 为字符串时会向循环变量状态表添加 `frame`、`total` 与 `progress` 三个变量，分别表示当前帧相对于当前行开始的序号、当前行总计持续的帧数、当前行的时间进度。

- 例子：每帧上显示当前帧序号
```
template line: !perframe("loop")!!loop.frame!
```

## autoload/remove-fx-lines.lua

移除所有通过模板生成的 `fx` 行，并解除 `karaoke` 模板行的注释状态。
