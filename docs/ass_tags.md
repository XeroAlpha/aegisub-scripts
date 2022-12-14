# 大概简单易懂的 ASS 特效标签速查表

翻译自 `ass-quickref.txt` 。

## 展示语法
- _<参数\>_
- _\[可选参数\]_
- <../..> 单选项（必须在多个中选一个填入）

## 换行
|代码|功能|助记|
|---|---|---|
|\n|手动换行（仅在手动换行模式下有效，即\q2，其他模式下表现为空格）|**n**ew line|
|\N|强制换行|**N**EW LINE|
|\h|强制空格|**h**ard space|

## 样式
样式标签需要使用 `{...}` 扩起。

|代码|功能|助记|
|---|---|---|
|\b<0/1/_字重_>|粗体字|**b**old|
|\i<0/1>|斜体字|**i**talic|
|\u<0/1>|下划线|**u**nderline|
|\s<0/1>|删除线|**s**trikeout|
|\bord<_粗细_>|描边|**bord**er|
|\\<x/y>bord<_粗细_>|在X/Y轴方向的描边| - |
|\shad<_偏移_>|阴影|**shad**ow|
|\\<x/y>shad<_偏移_>|在X/Y轴方向的阴影| - |
|\be<0/1/_次数_>|模糊边缘|**b**lur **e**dges|
|\blur<_强度_>|模糊边缘（高斯模糊）|**blur** edges|
|\fn<_字体名_>|字体|**f**ont **n**ame|
|\fs<_大小_>|字体大小|**f**ont **s**ize|
|\fsc<x/y><_百分比_>|在X/Y轴方向的字体缩放|**f**ont **sc**ale|
|\fsp<_间距像素_>|字间距|**f**ont **sp**acing|
|\fr<x/y/z><_角度_>|在X/Y/Z轴方向的旋转|**f**ont **r**otation|
|\fr<_角度_>| = \frz<_角度_> | - |
|\fa<x/y><_系数_>|字体剪切变换|**f**ont she**a**ring|
|\fe<_字符集_>|字符集|**f**ont **e**ncoding|
|\c&H\<_bbggrr_>&|字体颜色|**c**olor|
|\\<1/2/3/4>c&H\<_bbggrr_>&|字体/替换/描边/阴影颜色| - |
|\alpha&H\<_aa_>&|透明度|**a**lpha|
|\\<1/2/3/4>a&H\<_aa_>&|字体/替换/描边/阴影透明度| - |
|\an<_对齐方式_>|行对齐方式（小键盘）|**a**lignment **n**umpad|
|\a<_对齐方式_>|行对齐方式（传统SSA）| - |
|\k<_厘秒_>|卡拉OK字幕，未到达的音节显示为替换颜色|**k**araoke|
|\kf<_厘秒_>|卡拉OK字幕，从左至右逐渐填充|**k**araoke **f**illed from left to right|
|\ko<_厘秒_>|卡拉OK字幕，从左至右逐个显示描边|**k**araoke **o**utline highlighting|
|\K<_厘秒_>| = \kf<_厘秒_> | - |
|\q<0/1/2/3>|换行方式：<br />0 = 使行尽量等长<br />1 = 尽可能填满一行<br />2 = 手动换行<br />3 = 使行尽量等长，但多余的会放在底部| - |
|\r[<_样式名_>]|重置样式或改为其他样式|**r**eset|
|\pos(\<_x_>,\<_y_>)|字幕位置|**pos**ition|
|\move(\<_x1_>,\<_y1_>,\<_x2_>,\<_y2_>[,\<_t1_>,\<_t2_>])|字幕移动：(x1,y1) t1 -> t2 (x2,y2)|**move**|
|\org(\<_x_>,\<_y_>)|旋转中心|**or**i**g**in|
|\fad(\<_t1_>,\<_t2_>)|字幕淡入淡出：start->start+t1/end-t2->end|**fad**e|
|\fade(\<_a1_>,\<_a2_>,\<_a3_>,\<_t1_>,\<_t2_>,\<_t3_>,\<_t4_>)|字幕淡入淡出：a1,t1->a2,t2/a2,t3->a3,t4|**fade**|
|\t([\<_t1_>,\<_t2_>,]\[\<_系数_>,]<_样式代码_>|样式渐变动画（系数小于 0 逐渐减慢，反之则为逐渐加快）<br />插值曲线可表示为x‘=x^系数，x表示动画进行的进度，最小为0，最大为1|**t**ransformation|
|\clip(\<_x1_>,\<_y1_>,\<_x2_>,\<_y2_>)|矩形遮罩|**clip**|
|\clip([<_缩放系数_>,]\<_绘图指令_>)|矢量遮罩| - |
|\iclip(\<_x1_>,\<_y1_>,\<_x2_>,\<_y2_>)|反向矩形遮罩|**i**nverted **clip**|
|\iclip([<_缩放系数_>,]\<_绘图指令_>)|反向矢量遮罩| - |

## 绘图指令

绘图标签：

|代码|功能|助记|
|---|---|---|
|\p<0/1/_缩放系数_>|开启或关闭绘图指令<br />缩放系数：<br />0 - 关闭<br />1~ - 开启<br />大于1时绘制出的图形小2^(n-1)倍|**p**aint|
|\pbo<_偏移量_>|指定绘制基线在Y轴方向的偏移|**p**aint **b**aseline **o**ffset|

绘图指令：

|代码|功能|助记|
|---|---|---|
|m \<_x_> \<_y_>|将光标移至指定位置|**m**ove to|
|n \<_x_> \<_y_>|将光标移至指定位置，但不闭合之前的路径| - |
|l \<_x_> \<_y_>|将光标移至指定位置，并绘制线段路径|**l**ine to|
|b \<_x1_> \<_y1_> \<_x2_> \<_y2_> \<_x3_> \<_y3_>|将光标移至最后指定的位置，并根据光标和给定的三个控制点绘制三次贝塞尔曲线路径|**b**ezier to|
|s \<_x1_> \<_y1_> \<_x2_> \<_y2_> \<_x3_> \<_y3_> .. \<_xN_> \<_yN_>|将光标移至最后指定的位置，并根据光标和给定的N个途径点绘制B样条路径|b-**s**pline to|
|p \<_x_> \<_y_>|将光标移至指定位置，并延长已有的B样条路径| - |
|c|闭合B样条路径|**c**lose b-spline|