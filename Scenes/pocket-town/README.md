# 口袋小镇

车站、钟楼、桥和街屋随书页分层展开。屏幕打开超过 90° 后，火车自动发车并循环行驶；合到 90° 或以下时暂停，重新打开后从原处继续。道岔切换影响下一圈。书页已展开时也可点车站手动发一班车，完全收合后列车回到站台。

在仓库根目录运行 `python3 scripts/page.py preview pocket-town` 打开独立预览。预览以窗口下方的展开滑块模拟开合。用 `python3 scripts/page.py check pocket-town` 检查场景，用 `python3 scripts/page.py build pocket-town` 只打包预览。

首版交付列车玩法与分层展开。音效、街景细节和物理开合体验留待后续验收。整书是否启用本页由发布清单控制。
