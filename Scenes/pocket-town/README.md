# 口袋小镇

车站、钟楼、桥和街屋随书页分层展开。完全展开后，点钟楼前方的小道岔切换河岸线和钟楼线，再点左侧车站发车。一圈结束后可以再次发车。行驶中的列车保持本趟线路，低开合时回到起点。

在仓库根目录运行 `python3 scripts/page.py preview pocket-town` 打开独立预览。预览以窗口下方的展开滑块模拟开合。用 `python3 scripts/page.py check pocket-town` 检查场景，用 `python3 scripts/page.py build pocket-town` 只打包预览。

首版交付列车玩法与分层展开。音效、街景细节和物理开合体验留待后续验收。整书是否启用本页由发布清单控制。
