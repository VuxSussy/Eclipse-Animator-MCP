# Hướng dẫn cho người không biết code

Eclipse Animator MCP cho phép bạn **nói chuyện với Claude** để làm animation trong Roblox Studio. Bạn không cần viết code. Animation làm xong sẽ nằm sẵn trong Eclipse Animator để bạn chỉnh tiếp.

## Cài đặt (một lần)

1. Cài **Node.js** từ https://nodejs.org (bấm nút LTS).
2. Nếu muốn làm animation từ video, cài thêm **uv** và **ffmpeg**:
   - macOS: mở Terminal, gõ `brew install uv ffmpeg`
   - Windows: mở PowerShell, gõ `winget install astral-sh.uv Gyan.FFmpeg`
3. Tải repo này về (nút **Code → Download ZIP**), rồi giải nén.
4. Bấm đúp:
   - macOS: **`install.command`** (nếu máy chặn: chuột phải → Open)
   - Windows: **`install.bat`**
5. Khởi động lại **Roblox Studio** và **Claude**.
6. Trong Studio, khi plugin hỏi quyền gửi yêu cầu HTTP, bấm **Allow**.

Để kiểm tra: trong Studio, vào tab **Plugins** và bấm **AI Status**. Cửa sổ này hiện **● Connected to the AI app** khi Claude đang mở.

## Cách dùng

Mở place có nhân vật (rig) trong Studio, rồi nhắn cho Claude bằng lời của bạn. Ví dụ:

| Bạn muốn | Nhắn cho Claude |
|---|---|
| Tạo animation mới | "Làm animation nhân vật R15 vẫy tay chào rồi cúi đầu" |
| Xem thử | "Cho mình xem animation Wave" |
| Làm mượt và sống động hơn | "Enhance animation Wave, mạnh hơn một chút" |
| Lấy chuyển động từ video | "Làm animation từ video ~/Downloads/dance.mp4 cho rig R6" |
| Dùng animation pack của Roblox | "Lắp animation pack Ninja vào rig của mình" |

Bạn cũng có thể chọn lệnh có sẵn trong Claude (nút **+** hoặc gõ `/`): **Make an animation**, **Enhance an animation**, **Animation from a video**, **Use an animation pack**.

Mọi animation được lưu vào thư mục **AnimSaves** của rig. Mở **Eclipse Animator** là thấy và chỉnh tiếp được. Lỡ tay thì bấm **Ctrl+Z** (hoặc **Cmd+Z**) trong Studio để hoàn tác.

## Mẹo

- **Video**: quay một người, thấy rõ cả người, camera đứng yên, dài vài giây là tốt nhất. Có thể nói "chỉ lấy từ giây 2 đến giây 5".
- **Animation pack**: gõ tên gói (Ninja, Stylish, Robot, Zombie, Cartoony…) hoặc dán link `roblox.com/bundles/...`. Gói R15 vẫn lắp được lên rig R6, vì chuyển động được tự chuyển đổi.
- **Enhancer**: có thể nói "nhanh hơn", "mạnh hơn", "bớt nảy", "lặp mượt"…

## Giới hạn

- Hỗ trợ rig R6, R15 (cả loại khớp mới của Roblox) và đa số rig tự làm. Rig dùng Bone (mesh có xương) chưa được hỗ trợ.
- Animation từ video và từ pack đổi rig chỉ lấy góc xoay. Nhân vật đứng tại chỗ, không di chuyển theo, và các khớp không xoay vặn quanh trục của chính nó.
- Kết quả từ video là bản nháp tốt. Bạn nên chỉnh lại trong Eclipse Animator.
