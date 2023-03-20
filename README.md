# SightGuide

## 项目结构

项目使用经典 MVC 模式，主要分为以下几个文件夹：

- Main：主要为 `MainViewController`，这是 app 启动时的界面。另有：
  - `SceneModel`：这个文件中是 app 用到的所有数据模型
- Glance：主要为 `GlanceViewController`，这是 Glance 模块的界面。另有：
  - `GlanceCollectionViewCell`，这是 Glance 界面左右滚动的卡片
- Fixation：主要为 `FixationViewController`，这是 Fixation 模块的界面。另有：
  - `FixationItemView`，这是 Fixation 界面显示的物体框
- Memory：主要为 `MemoryViewController`，这是 Memory 模块的界面。另有：
  - `MemoryCollectionViewCell`，这是 Memory 界面显示 label 的一行
  - `MemorySectionHeaderView`，这是 Memory 界面的 section header
- Sharing：主要为 `SharingViewController`，这是 Sharing 模块的界面，目前为空。
- Helpers：这里是一些工具类。包括：
  - Toast：用来在屏幕下方显示一个小 toast。
  - NavigationTopViewController: 切换横竖屏时用到的工具方法。
  - Specs：包含用到的颜色。
  - AudioHelper：包含录音和播放录音功能。
- Resources：这里是 app 用到的资源文件，包括图片、音频和 mock 数据。

下面介绍几个主要模块。

## Glance

### 界面

这个界面从 `GlanceViewController.xib` 中加载得出。上下是固定的笑脸/哭脸 emoji 和文字 label，中间是一个 `UICollectionView`，用于显示横向滚动的卡片。

### 初始化

界面初始化流程如下：

- 调用 `setupViewController` 初始化 collectionView
- 调用 `setupAudioPlayer` 初始化音频播放和语音播报
- 调用 `setupSwipeGesture` 添加三指滑动手势和上滑、下滑手势
- 调用 `setupDoubleTapGesture` 添加双指双击手势

每当界面显示时（包括从其他界面返回）：

- 调用 `playFixedPrompt` 播放固定提示语
> 注意：如果有录好的固定提示语，可替换 Resource 文件夹下的 `glance_fixed_promt` 文件，并将 `playFixedPrompt` 中的代码改为目前注释掉的代码。
- 调用 `parseSceneFromJSON` 加载数据
> 注意：此处的数据目前为 mock 数据，后续需要改为从后端接口获取数据。

> 注意：每次获取数据后，将所有的 objs 的 ID 保存在 `seenObjs` 中用于去重。由于 mock 数据不会变化，目前去重的逻辑被注释掉。
- 刷新界面
- 固定提示语播报结束后，调用 `readCurrentSceneItem` 开始朗读物体信息

### 朗读物体信息

- 将 `collectionView` 滚动到当前物体
- 调用 `readCurrentSceneItem` 朗读当前物体说明
- 朗读完毕后，触发 `speechSynthesizer(didFinish:)`方法，开启计时器。间隔 1s 后，朗读下一个物体

### 手势

- 三指向下滑动，触发 `threeFingerSwipeDownGestureHandler`，present 一个 `FixationViewController`
- 双击物体卡片，会使用 `selectedItemIndex` 记录物体选中状态
- 单指向上或向下滑动，触发 `swipeGestureHandler`。如果有选中状态的物体，则标记喜欢/不感兴趣
  - 目前的逻辑是在滚动到下一个物体时，清除上一个物体的选中状态，这段逻辑在 `readCurrentSceneItem` 中，如果不符合需求可以去掉
> 注意：目前标记 喜欢/不感兴趣 没有调用接口，而是使用底部一个小 toast 表示。后续需要改为请求后端接口。
- 双指双击，触发 `doubleTapWithTwoFingersGestureHandler` 将语音播报暂停，再次触发时继续。

## Fixation

### 界面

这个界面从 `FixationViewController.xib` 中加载得出。底层是一个 `UIImage` 用于显示底图。上面使用代码绘制物体框。

> 注意：目前底图为固定。后续需要改为从后端获取。

### 初始化

界面初始化流程如下：

- 将 app 切换为横屏
- 调用 `setupGestures` 添加手势
- 调用 `setupAudioPlayer` 初始化语音播放
- 调用 `setupFixationItemViews` 绘制物体框
  - 目前绘制了 20 个，所以最多可以显示 20 个物体框。需要时可以再增加。
  
当界面显示后：

- 调用 `parseAndRenderSubScene` 或 `parseAndRenderMainScene` 加载 mock 数据，然后调用 `renderFixationItemViews` 刷新页面
  - 维护标志位 `isRootScene` 表示这是进入 FixationViewController 的场景（取值为 `true`），还是双击后展开的子场景（取值为 `false`）
> 注意：为了避免切换横屏后的 bug，所以把刷新时机推迟到 `viewDidAppear` 中
> 注意：此处的数据目前为 mock 数据，后续需要改为从后端接口获取数据。
- 朗读“欢迎探索【场景名称】”

当界面退出后：

- 将 app 切换为竖屏

### 手势

- 三指上滑：调用 `handleThreeFingerSwipeUpGesture` 退出当前界面
- 单指滑动：调用 `handlePanGesture`
  - 如果接触点与物体框重合，则调用 `setFocusedItemView` 选中物体框
    - 将选中的物体框边框加粗
    - 使用 `beepAudioPlayer` 播放“滴”声
    - 启动计时器，1s 后触发 `readLastTouchedView` 朗读物体框
      - 如果是从 memory 进入，朗读“【物体名称】【有/无】标签”
      - 否则只朗读“【物体名称】”
  - 如果接触点离开物体框，则调用 `cancelFocusedItemView` 取消选中
  - 如果手指离开屏幕，只清空计时器，不取消选中
- 双指左滑：调用 `handleTwoFingerSwipeLeftGesture`
  - 如果当前在双击展开后的子场景：返回主场景
  - 如果当前在主场景：
    - 如果是从 memory 进入的：朗读“为您返回标签目录”。朗读完成后，返回 memory。
    - 否则无操作
- 单击物体框：调用 `handleTapItemViewGesture`
  - 如果是从 memory 进入的，且物体有标签：播放录音
  - 否则朗读物体描述
- 双击物体框：调用 `handleDoubleTapItemViewGesture`
  - 如果当前在主场景（非双击展开后的子场景）且双击的物体可以展开，则展开子场景：加载子场景数据，并刷新界面
  > 注意：此处的数据目前为 mock 数据，后续需要改为从后端接口获取数据。
- 双指双击后长按 3s：开始时调用 `markFocusedItemView`，手指放开后调用 `endMarkFocusedItemView`
  - 朗读 "您已标记，继续长按可录音添加标签"
  - 朗读完毕后如果仍在长按，调用 `AudioHelper.startRecording` 开始录音
  - 手指放开后：
    - 调用 `AudioHelper.endRecording` 结束录音
    - 朗读 "您已为【物体名称】【制作/修改】录音标签"
    - 在物体框上显示圆点
    > 注意：未上传录音。后续需要调用后端接口上传录音文件。

## Memory

### 界面

这个界面从 `MemoryViewController.xib` 中加载得出。主体是一个 collectionView。

### 初始化

- 朗读“请选择标签”
- 初始化 collectionView
- 加载 mock 数据，并刷新界面
> 注意：此处的数据目前为 mock 数据，后续需要改为从后端接口获取数据。
- 初始化音频播放
- 初始化手势

### 手势

- 单指滑动：调用 `handlePanGesture`
  - 如果滑动到 cell 上：
    - 标记选中
    - 播放“滴”声
    - 开始计时，2s 后调用 `readMemory`
      - 朗读标签名称
      - 结束后，播放录音
  - 否则取消选中，停止计时
- 双击 cell：调用 `handleDoubleTapCell`
  - 朗读 "为您展开场景标签"
  - 结束后，跳转到 `FixationViewController`
  > 注意：如果不再用 mock 数据，从 `FixationViewController` 返回后，`memory` 界面数据可能需要重新请求和刷新。
