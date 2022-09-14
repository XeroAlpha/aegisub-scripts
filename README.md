# ProjectXero's Aegisub scripts

本仓库用于放一些我常用的 [Aegisub](https://github.com/Ristellise/AegisubDC) 脚本，旨在快速开发特效，缩短开发时间。基于 BSD 3-Clause 协议开源。

## autoload/ln.kara-templater-mod.lua

这是一个修改过的卡拉OK模板脚本，放置于 `autoload` 目录下自动加载即可。

原仓库：[logarrhythmic/karaOK](https://github.com/logarrhythmic/karaOK)。

我在 logarrhythmic 修改版本的基础上增加了部分函数。

### load_fx(effect)

寻找第一个包含 `fx <effect>` 的模板行，为其创建执行函数 `run(extra)` 并返回。

通过此函数可以方便地复用模板行，使得模板行中可以插入其他模板行，以便于统一修改参数。

此外支持通过内联变量自定义参数，将内联变量构成的表传入执行函数的 `extra` 参数即可。

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

寻找包含 `fx <effect>` 的模板行，并在当前作用域下执行模板。

无需指定自定义参数的情况下 `extra` 可省略。等效于带缓存的 `load_fx(effect)(extra)`。

- 例子：复用文字与边界透明度配置，支持配置透明度
```
template line fx c: {\1a$alpha1\3a$alpha3}
template line: !use_fx("c",{alpha1="&HFF&",alpha3="&H00&"})!{\pos(100,100)}
[result]: {\1a&HFF&\3a&HFF&}{\pos(100,100)}
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

变体 `locate_c(ox, oy, x, y, align)` 返回一个包含坐标的表。

变体 `locate_s(ox, oy, x, y, align)` 返回空格分隔的坐标字符串。

- 例子：逐字模板位置设定
```
{\pos(100,100)}Test line
template char: {\pos(!locate()!)}
```

### define(name, value)

在内联变量中定义新变量，或修改已有变量的值。变量名只能包含小写字母与下划线。

已定义的内联变量可通过 `varctx` 表来访问，但 `use_fx` 与 `load_fx` 的自定义参数除外。

自动生成的内联变量会覆盖使用此函数定义的内联变量。

- 例子：通过内联变量修改参数
```
code once: define("myvar", 1.2);
template line: {\frz$myvar}
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

## autoload/remove-fx-lines.lua

移除所有通过模板生成的 `fx` 行，并解除 `karaoke` 模板行的注释状态。