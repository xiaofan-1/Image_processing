import sys
import socket
import time
import numpy as np
import cv2

try:
    from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
                                 QLabel, QLineEdit, QPushButton, QCheckBox, QFrame,
                                 QRadioButton, QButtonGroup, QComboBox)
    from PyQt5.QtCore import Qt, QThread, pyqtSignal, pyqtSlot
    from PyQt5.QtGui import QImage, QPixmap, QFont, QIcon
except ImportError:
    print("模块缺失！请在命令行执行: pip install PyQt5 opencv-python numpy")
    sys.exit(1)

QSS = """
QWidget {
    background-color: #1A1A1A;
    color: #E0E0E0;
    font-family: 'Segoe UI', 'Microsoft YaHei', sans-serif;
}
QLabel {
    font-size: 14px;
}
QLineEdit {
    background-color: #2D2D2D;
    border: 1px solid #4D4D4D;
    border-radius: 6px;
    padding: 8px;
    color: #FFFFFF;
    font-size: 14px;
}
QLineEdit:focus {
    border: 1px solid #4A90E2;
}
QPushButton {
    background-color: #4A90E2;
    color: white;
    border: none;
    border-radius: 6px;
    padding: 10px 16px;
    font-size: 15px;
    font-weight: bold;
}
QPushButton:hover {
    background-color: #357ABD;
}
QPushButton:pressed {
    background-color: #2A5F96;
}
QPushButton:disabled {
    background-color: #4D4D4D;
    color: #888888;
}
QCheckBox {
    font-size: 14px;
    padding: 5px;
}
QCheckBox::indicator {
    width: 18px;
    height: 18px;
    border-radius: 4px;
    border: 1px solid #4D4D4D;
    background-color: #2D2D2D;
}
QCheckBox::indicator:checked {
    background-color: #4A90E2;
    border: 1px solid #4A90E2;
}
"""

class VideoReceiverThread(QThread):
    frame_ready = pyqtSignal(np.ndarray)
    fps_update = pyqtSignal(float)
    speed_update = pyqtSignal(float)
    error_update = pyqtSignal(str)
    status_update = pyqtSignal(str)
    
    def __init__(self, ip, port, width=1280, height=720):
        super().__init__()
        self.ip = ip
        self.port = port
        self.width = width
        self.height = height
        self.running = False
        self.swap_bytes = False
        self.pixel_format = 'RGB565'  # 'RGB565' or 'RGB888'
        self.sock = None
        self.bytes_received = 0
        self.speed_update_time = 0

    def run(self):
        self.running = True
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.sock.bind((self.ip, self.port))
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 16 * 1024 * 1024)
            self.sock.settimeout(1.0)
        except Exception as e:
            self.error_update.emit(f"绑定端口失败: {e}")
            return

        bpp = 2 if self.pixel_format == 'RGB565' else 3  # bytes per pixel
        expected_bytes = self.width * self.height * bpp
        frame_bytes = bytearray()
        frames_count = 0
        start_time = time.time()
        self.speed_update_time = start_time
        last_cnt_h = -1
        
        # 统计变量
        total_packets_received = 0
        total_packets_dropped = 0
        total_frames_completed = 0
        total_frames_dropped = 0
        total_bytes_received_all = 0
        session_start_time = time.time()
        
        # 打开日志文件追加模式
        log_filepath = "drop_log.txt"
        import datetime
        cur_time_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        try:
            log_file = open(log_filepath, "w", encoding="utf-8")
            log_file.write(f"\n===开始监听视频流: {cur_time_str}===\n")
        except:
            log_file = None
        
        while self.running:
            try:
                packet, addr = self.sock.recvfrom(65536)
            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    self.error_update.emit(f"接收出错: {e}")
                break
                
            packet_len = len(packet)
            
            total_packets_received += 1
            total_bytes_received_all += packet_len
            
            self.bytes_received += packet_len
            current_time = time.time()
            if current_time - self.speed_update_time >= 1.0:
                speed_mbps = (self.bytes_received * 8) / (current_time - self.speed_update_time) / 1000000
                self.speed_update.emit(speed_mbps)
                self.bytes_received = 0
                self.speed_update_time = current_time
            
            # 解析您的新协议
            if packet_len == 4:
                # 检查帧头和帧尾
                if packet == b'\xFA\x32\x69\x44':
                    # 帧头，清空当前累积的数据，准备接收新一帧
                    frame_bytes.clear()
                    last_cnt_h = -1
                elif packet == b'\xFA\xCC\xCC\xAF':
                    # 帧尾，说明一帧接收完毕，开始处理图像
                    if len(frame_bytes) == expected_bytes:
                        total_frames_completed += 1
                        # 极速解析
                        raw = np.frombuffer(frame_bytes, dtype=np.uint8).copy()  # .copy() 断开对 frame_bytes 的引用

                        if self.pixel_format == 'RGB565':
                            raw_data = raw.reshape(-1, 2).copy()
                            # FPGA 高字节先发（大端），byteswap() 纠正字节序
                            data16 = raw_data.view(np.uint16).byteswap()
                            if self.swap_bytes:
                                data16 = data16.byteswap()
                            data16 = data16.reshape(self.height, self.width)
                            R = ((data16 & 0xF800) >> 8).astype(np.uint8)
                            G = ((data16 & 0x07E0) >> 3).astype(np.uint8)
                            B = ((data16 & 0x001F) << 3).astype(np.uint8)
                            bgr_img = np.dstack((B, G, R))
                        else:  # RGB888
                            raw_data = raw.reshape(self.height, self.width, 3).copy()
                            if self.swap_bytes:  # 勾选时 RGB→BGR 互换
                                bgr_img = raw_data[:, :, ::-1]
                            else:
                                bgr_img = raw_data[:, :, [2, 1, 0]]  # RGB→BGR for OpenCV
                        self.frame_ready.emit(bgr_img)
                        
                        frames_count += 1
                        if frames_count % 30 == 0:
                            fps = 30 / (time.time() - start_time)
                            self.fps_update.emit(fps)
                            start_time = time.time()
                    else:
                        total_frames_dropped += 1
                        # 帧数据长度不够说明有丢包，这一帧直接废弃
                        pass
                    
                    # 无论成功失败，处理完帧尾后清理缓存
                    frame_bytes.clear()
            else:
                # 检查视频数据包 (包头是 FA, 尾是 AF)
                if packet_len > 4 and packet[0] == 0xFA and packet[-1] == 0xAF:
                    # 现在 FPGA 在 AF 前加了 2 字节的 cnt_h
                    # packet 结构: [FA] + [1280字节图像] + [cnt_h高8位] + [cnt_h低8位] + [AF]
                    # 提取图像数据: 从第 1 个字节开始，到倒数第 3 个字节为止
                    image_payload = packet[1:-3]
                    
                    # 提取包序号 cnt_h (可选，用于调试丢了哪一个包)
                    cnt_h = (packet[-3] << 8) | packet[-2]
                    
                    if last_cnt_h != -1 and cnt_h != last_cnt_h + 1:
                        dropped = cnt_h - last_cnt_h - 1
                        if dropped > 0:
                            total_packets_dropped += dropped
                            # 写入带时间戳和帧号的日志
                            if log_file:
                                import datetime
                                ts = datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]
                                log_file.write(f"[{ts}] 帧号 {frames_count+1:>5} | 丢失 {dropped:4d} 包 | 遗漏序号段: [{last_cnt_h+1:>4} ~ {cnt_h-1:>4}]\n")
                                log_file.flush()
                    last_cnt_h = cnt_h
                    
                    frame_bytes.extend(image_payload)
                else:
                    # 不符合协议的包，直接丢弃或打印日志
                    pass
                    
        if self.sock:
            self.sock.close()
        if log_file:
            session_end_time = time.time()
            total_time = session_end_time - session_start_time
            if total_time <= 0: total_time = 0.001
            
            avg_speed_mbps = (total_bytes_received_all * 8) / total_time / 1000000
            avg_fps = total_frames_completed / total_time
            
            pkt_total = total_packets_received + total_packets_dropped
            pkt_drop_rate = (total_packets_dropped / pkt_total * 100) if pkt_total > 0 else 0
            
            frm_total = total_frames_completed + total_frames_dropped
            frm_drop_rate = (total_frames_dropped / frm_total * 100) if frm_total > 0 else 0
            
            summary = (
                f"\n===================== 监听结束统计摘要 =====================\n"
                f"[时 间] 监听总时长 : {total_time:.2f} 秒\n"
                f"----------------------------------------------------------\n"
                f"[网 速] 接收总数据 : {total_bytes_received_all / 1024 / 1024:.2f} MB\n"
                f"        平均速率   : {avg_speed_mbps:.2f} Mbps\n"
                f"----------------------------------------------------------\n"
                f"[帧 率] 完整接收帧 : {total_frames_completed} 帧 (平均帧率: {avg_fps:.1f} fps)\n"
                f"        损坏丢弃帧 : {total_frames_dropped} 帧\n"
                f"        整体丢帧率 : {frm_drop_rate:.2f}%\n"
                f"----------------------------------------------------------\n"
                f"[底 层] 成功接收包 : {total_packets_received} 包\n"
                f"        网络丢失包 : {total_packets_dropped} 包\n"
                f"        底层丢包率 : {pkt_drop_rate:.4f}%\n"
                f"==========================================================\n"
            )
            log_file.write(summary)
            log_file.close()

    def stop(self):
        self.running = False
        self.wait()

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("派大星-以太网视频传输助手")
        self.setWindowIcon(QIcon(r"d:\mpj\ddr3_test\reverbnation_apps_platform_icon_176111.ico"))
        self.resize(1200, 800)
        self.setStyleSheet(QSS)
        
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        
        main_layout = QHBoxLayout(main_widget)
        main_layout.setContentsMargins(20, 20, 20, 20)
        main_layout.setSpacing(20)
        
        # 左侧控制面板
        left_panel = QWidget()
        left_panel.setFixedWidth(300)
        left_layout = QVBoxLayout(left_panel)
        left_layout.setContentsMargins(0, 0, 0, 0)
        left_layout.setSpacing(15)
        
        title_label = QLabel("FPGA 视频传输")
        title_label.setFont(QFont("Microsoft YaHei", 20, QFont.Bold))
        title_label.setStyleSheet("color: #4A90E2;")
        left_layout.addWidget(title_label)
        
        # 添加 QComboBox
        from PyQt5.QtWidgets import QComboBox
        left_layout.addWidget(QLabel("监听 IP 地址:"))
        self.ip_combo = QComboBox()
        self.ip_combo.setStyleSheet("""
            QComboBox {
                background-color: #2D2D2D;
                border: 1px solid #4D4D4D;
                border-radius: 6px;
                padding: 8px;
                color: #FFFFFF;
                font-size: 14px;
            }
            QComboBox::drop-down { border: none; }
        """)
        # 获取所有本地 IP
        ips = ["0.0.0.0 (监听所有)"]
        try:
            for interface in socket.getaddrinfo(socket.gethostname(), None):
                ip = interface[4][0]
                if ip not in ips and ":" not in ip: # 排除 IPv6 和重复项
                    ips.append(ip)
        except Exception:
            pass
        self.ip_combo.addItems(ips)
        left_layout.addWidget(self.ip_combo)
        
        left_layout.addWidget(QLabel("监听 端口号:"))
        self.port_input = QLineEdit("5678")
        left_layout.addWidget(self.port_input)
        
        left_layout.addWidget(QLabel("水平分辨率 (Width):"))
        self.width_input = QLineEdit("1280")
        left_layout.addWidget(self.width_input)
        
        left_layout.addWidget(QLabel("垂直分辨率 (Height):"))
        self.height_input = QLineEdit("720")
        left_layout.addWidget(self.height_input)
        
        self.swap_checkbox = QCheckBox("🔥 翻转字节序 / 通道序")
        self.swap_checkbox.setToolTip("RGB565: 翻转高低字节\nRGB888: R↔B 通道互换")
        self.swap_checkbox.stateChanged.connect(self.on_swap_changed)

        radio_row = QWidget()
        radio_layout = QHBoxLayout(radio_row)
        radio_layout.setContentsMargins(0, 0, 0, 0)
        radio_layout.setSpacing(12)
        self.rgb565_radio = QRadioButton("RGB565")
        self.rgb888_radio = QRadioButton("RGB888")
        self.rgb565_radio.setChecked(True)  # 默认 RGB565
        self.fmt_group = QButtonGroup()
        self.fmt_group.addButton(self.rgb565_radio)
        self.fmt_group.addButton(self.rgb888_radio)
        radio_layout.addWidget(self.rgb565_radio)
        radio_layout.addWidget(self.rgb888_radio)
        radio_layout.addStretch()
        left_layout.addWidget(radio_row)
        left_layout.addWidget(self.swap_checkbox)
        
        self.btn_start = QPushButton("▶ 开始监听实时画面")
        self.btn_start.setFixedHeight(45)
        self.btn_start.clicked.connect(self.start_listening)
        left_layout.addWidget(self.btn_start)
        
        self.btn_stop = QPushButton("⏹ 停止监听")
        self.btn_stop.setFixedHeight(45)
        self.btn_stop.setStyleSheet("""
            QPushButton { background-color: #E74C3C; }
            QPushButton:hover { background-color: #C0392B; }
            QPushButton:disabled { background-color: #4D4D4D; }
        """)
        self.btn_stop.setEnabled(False)
        self.btn_stop.clicked.connect(self.stop_listening)
        left_layout.addWidget(self.btn_stop)
        
        self.status_label = QLabel("状态: ⚪ 等待启动")
        self.status_label.setStyleSheet("color: #AAAAAA; margin-top: 20px;")
        self.status_label.setWordWrap(True)  # 允许自动换行，防止文字过长被截断
        left_layout.addWidget(self.status_label)
        
        self.fps_label = QLabel("帧率: 0.00 fps")
        self.fps_label.setStyleSheet("color: #2ECC71; font-size: 24px; font-weight: bold;")
        left_layout.addWidget(self.fps_label)
        
        self.speed_label = QLabel("速率: 0.00 Mbps")
        self.speed_label.setStyleSheet("color: #3498DB; font-size: 24px; font-weight: bold;")
        left_layout.addWidget(self.speed_label)
        
        left_layout.addStretch()
        main_layout.addWidget(left_panel)
        
        # 右侧视频画面
        self.video_frame = QLabel()
        self.video_frame.setAlignment(Qt.AlignCenter)
        self.video_frame.setText("等待视频连接...")
        self.video_frame.setStyleSheet("""
            background-color: qlineargradient(
                spread:pad, x1:0, y1:0, x2:1, y2:1,
                stop:0 #3A3A3A, stop:0.5 #4A4A4A, stop:1 #3A3A3A);
            border: 2px dashed #6A6A6A;
            border-radius: 10px;
            font-size: 24px;
            color: #AAAAAA;
        """)
        self.video_frame.setMinimumSize(640, 360)
        main_layout.addWidget(self.video_frame, 1)
        
        self.receiver_thread = None

    def start_listening(self):
        ip = self.ip_combo.currentText().split(" ")[0]
        if ip == "0.0.0.0":
            ip = "0.0.0.0"
        try:
            port = int(self.port_input.text())
            w = int(self.width_input.text())
            h = int(self.height_input.text())
        except ValueError:
            self.status_label.setText("状态: 🔴 参数格式错误")
            self.status_label.setStyleSheet("color: #E74C3C;")
            return
            
        self.receiver_thread = VideoReceiverThread(ip, port, w, h)
        self.receiver_thread.swap_bytes = self.swap_checkbox.isChecked()
        self.receiver_thread.pixel_format = 'RGB888' if self.rgb888_radio.isChecked() else 'RGB565'
        self.receiver_thread.frame_ready.connect(self.update_image)
        self.receiver_thread.fps_update.connect(self.update_fps)
        self.receiver_thread.speed_update.connect(self.update_speed)
        self.receiver_thread.error_update.connect(self.update_error)
        self.receiver_thread.status_update.connect(self.update_status)
        
        self.receiver_thread.start()
        
        self.btn_start.setEnabled(False)
        self.btn_stop.setEnabled(True)
        self.ip_combo.setEnabled(False)
        self.port_input.setEnabled(False)
        self.width_input.setEnabled(False)
        self.height_input.setEnabled(False)
        self.rgb565_radio.setEnabled(False)
        self.rgb888_radio.setEnabled(False)
        self.status_label.setText(f"状态: 🟢 正在监听 {ip}:{port}")
        self.status_label.setStyleSheet("color: #2ECC71;")
        
        self.video_frame.setText("等待第一帧到达...")

    def stop_listening(self):
        if self.receiver_thread:
            self.receiver_thread.stop()
            self.receiver_thread = None
            
        self.btn_start.setEnabled(True)
        self.btn_stop.setEnabled(False)
        self.ip_combo.setEnabled(True)
        self.port_input.setEnabled(True)
        self.width_input.setEnabled(True)
        self.height_input.setEnabled(True)
        self.rgb565_radio.setEnabled(True)
        self.rgb888_radio.setEnabled(True)
        self.status_label.setText("状态: ⚪ 已停止")
        self.status_label.setStyleSheet("color: #AAAAAA;")
        self.fps_label.setText("帧率: 0.00 fps")
        self.speed_label.setText("速率: 0.00 Mbps")
        self.video_frame.clear()
        self.video_frame.setText("视频流已停止...")

    def on_swap_changed(self, state):
        if self.receiver_thread:
            self.receiver_thread.swap_bytes = bool(state)

    @pyqtSlot(np.ndarray)
    def update_image(self, bgr_img):
        # 转换 OpenCV BGR 到 PyQt RGB
        rgb_img = cv2.cvtColor(bgr_img, cv2.COLOR_BGR2RGB)
        h, w, ch = rgb_img.shape
        bytes_per_line = ch * w
        qimg = QImage(rgb_img.data, w, h, bytes_per_line, QImage.Format_RGB888)
        pixmap = QPixmap.fromImage(qimg)
        
        # 完美自适应缩放，保持长宽比
        scaled_pixmap = pixmap.scaled(self.video_frame.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation)
        self.video_frame.setPixmap(scaled_pixmap)

    @pyqtSlot(float)
    def update_fps(self, fps):
        self.fps_label.setText(f"帧率: {fps:.2f} fps")

    @pyqtSlot(float)
    def update_speed(self, speed):
        self.speed_label.setText(f"速率: {speed:.2f} Mbps")

    @pyqtSlot(str)
    def update_error(self, err_msg):
        self.status_label.setText(f"状态: 🟠 {err_msg}")
        self.status_label.setStyleSheet("color: #F39C12;")

    @pyqtSlot(str)
    def update_status(self, msg):
        current_text = self.status_label.text()
        if "🟠" in current_text:  # 只有处于报错状态时才恢复，避免闪烁
            ip = self.ip_combo.currentText().split(" ")[0]
            if ip == "0.0.0.0": ip = "0.0.0.0"
            port = self.port_input.text()
            self.status_label.setText(f"状态: 🟢 正在监听 {ip}:{port} ({msg})")
            self.status_label.setStyleSheet("color: #2ECC71;")

    def closeEvent(self, event):
        self.stop_listening()
        event.accept()

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())
