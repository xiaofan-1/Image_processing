#include "mainwindow.h"
#include <QImage>
#include <QPixmap>
#include <QNetworkInterface>
#include <QDateTime>
#include <QIcon>

// =========================================================
// UI 样式表 (与你 Python 版本完全一致 1:1 移植)
// =========================================================
const QString QSS = R"(
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
QPushButton:hover { background-color: #357ABD; }
QPushButton:pressed { background-color: #2A5F96; }
QPushButton:disabled { background-color: #4D4D4D; color: #888888; }
QCheckBox { font-size: 14px; padding: 5px; }
QCheckBox::indicator {
    width: 18px; height: 18px;
    border-radius: 4px;
    border: 1px solid #4D4D4D;
    background-color: #2D2D2D;
}
QCheckBox::indicator:checked {
    background-color: #4A90E2;
    border: 1px solid #4A90E2;
}
QComboBox {
    background-color: #2D2D2D; border: 1px solid #4D4D4D;
    border-radius: 6px; padding: 8px; color: #FFFFFF; font-size: 14px;
}
QComboBox::drop-down { border: none; }
)";

// =========================================================
// VideoWorker 独立底层接收与处理线程
// =========================================================
VideoWorker::VideoWorker(QString ip, quint16 port, int w, int h, bool swap, bool isRgb565)
    : m_ip(ip), m_port(port), m_width(w), m_height(h), m_swapBytes(swap), m_isRgb565(isRgb565)
{
    udpSocket = nullptr;
    logFile = nullptr;
    logStream = nullptr;
    expectedBytes = m_width * m_height * (m_isRgb565 ? 2 : 3);
    last_cnt_h = -1;
    bytesReceivedForSpeed = 0;
    framesCount = 0;
}

VideoWorker::~VideoWorker() {
    if(udpSocket) {
        udpSocket->close();
        udpSocket->deleteLater();
    }
}

void VideoWorker::startWork() {
    udpSocket = new QUdpSocket();

    QHostAddress bindAddress = (m_ip == "0.0.0.0" || m_ip.startsWith("0.0.0.0")) ? QHostAddress::Any : QHostAddress(m_ip);

    if(!udpSocket->bind(bindAddress, m_port, QAbstractSocket::ShareAddress | QAbstractSocket::ReuseAddressHint)) {
        emit statusUpdated(QString("绑定端口失败"), true);
        emit finished();
        return;
    }
    // C++ 魔法：开辟 16MB 内核接收缓冲区
    udpSocket->setSocketOption(QAbstractSocket::ReceiveBufferSizeSocketOption, 16 * 1024 * 1024);

    connect(udpSocket, &QUdpSocket::readyRead, this, &VideoWorker::readPendingDatagrams);

    statsTimer = new QTimer(this);
    connect(statsTimer, &QTimer::timeout, this, &VideoWorker::calculateStats);
    statsTimer->start(1000); // 1秒更新一次网速

    // 初始化日志与统计变量
    totalPacketsReceived = 0;
    totalPacketsDropped = 0;
    totalFramesCompleted = 0;
    totalFramesDropped = 0;
    totalBytesReceivedAll = 0;
    framesCountForLog = 0;
    sessionStartTime = QDateTime::currentMSecsSinceEpoch();

    logFile = new QFile("udp_log.txt");
    if (logFile->open(QIODevice::WriteOnly | QIODevice::Text)) {
        logStream = new QTextStream(logFile);
        // 强制使用 UTF-8 并加上 BOM 头，彻底解决乱码
        logStream->setCodec("UTF-8");
        logStream->setGenerateByteOrderMark(true);
        QString curTime = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
        *logStream << QString::fromUtf8("\n===开始监听视频流: ") << curTime << QString::fromUtf8("===\n");
    } else {
        logStream = nullptr;
    }

    fpsTimer.start();
    emit statusUpdated(QString("正在监听 %1:%2").arg(m_ip).arg(m_port), false);
}

void VideoWorker::stopWork() {
    if (statsTimer) statsTimer->stop();
    if (udpSocket) udpSocket->close();

    // 停止时打印总结报告
    if (logStream) {
        qint64 sessionEndTime = QDateTime::currentMSecsSinceEpoch();
        double totalTime = (sessionEndTime - sessionStartTime) / 1000.0;
        if (totalTime <= 0) totalTime = 0.001;

        double avg_speed_mbps = (totalBytesReceivedAll * 8.0) / totalTime / 1000000.0;
        double avg_fps = totalFramesCompleted / totalTime;

        uint64_t pkt_total = totalPacketsReceived + totalPacketsDropped;
        double pkt_drop_rate = pkt_total > 0 ? (totalPacketsDropped * 100.0 / pkt_total) : 0.0;

        uint64_t frm_total = totalFramesCompleted + totalFramesDropped;
        double frm_drop_rate = frm_total > 0 ? (totalFramesDropped * 100.0 / frm_total) : 0.0;

        *logStream << QString::fromUtf8("\n===================== 监听结束统计摘要 =====================\n")
                   << QString::fromUtf8("[时 间] 监听总时长 : %1 秒\n").arg(totalTime, 0, 'f', 2)
                   << QString::fromUtf8("----------------------------------------------------------\n")
                   << QString::fromUtf8("[网 速] 接收总数据 : %1 MB\n").arg(totalBytesReceivedAll / 1024.0 / 1024.0, 0, 'f', 2)
                   << QString::fromUtf8("        平均速率   : %1 Mbps\n").arg(avg_speed_mbps, 0, 'f', 2)
                   << QString::fromUtf8("----------------------------------------------------------\n")
                   << QString::fromUtf8("[帧 率] 完整接收帧 : %1 帧 (平均帧率: %2 fps)\n").arg(totalFramesCompleted).arg(avg_fps, 0, 'f', 1)
                   << QString::fromUtf8("        损坏丢弃帧 : %1 帧\n").arg(totalFramesDropped)
                   << QString::fromUtf8("        整体丢帧率 : %1%\n").arg(frm_drop_rate, 0, 'f', 2)
                   << QString::fromUtf8("----------------------------------------------------------\n")
                   << QString::fromUtf8("[底 层] 成功接收包 : %1 包\n").arg(totalPacketsReceived)
                   << QString::fromUtf8("        网络丢失包 : %1 包\n").arg(totalPacketsDropped)
                   << QString::fromUtf8("        底层丢包率 : %1%\n").arg(pkt_drop_rate, 0, 'f', 4)
                   << QString::fromUtf8("==========================================================\n");

        logFile->close();
        delete logFile;
        logFile = nullptr;
        logStream = nullptr;
    }

    emit finished();
}

void VideoWorker::setSwap(bool swap) {
    m_swapBytes = swap;
}

void VideoWorker::calculateStats() {
    double speed_mbps = (bytesReceivedForSpeed * 8.0) / 1000000.0;
    bytesReceivedForSpeed = 0;

    double fps = 0;
    if (fpsTimer.elapsed() > 0) {
        fps = (framesCount * 1000.0) / fpsTimer.elapsed();
    }
    emit statsUpdated(fps, speed_mbps);

    framesCount = 0;
    fpsTimer.restart();
}

void VideoWorker::readPendingDatagrams() {
    while (udpSocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(udpSocket->pendingDatagramSize());
        udpSocket->readDatagram(datagram.data(), datagram.size());

        int len = datagram.size();
        bytesReceivedForSpeed += len;

        totalPacketsReceived++;
        totalBytesReceivedAll += len;

        if (len == 4) {
            if (datagram == QByteArray::fromHex("FA326944")) {
                frameBuffer.clear();
                last_cnt_h = -1;
            }
            else if (datagram == QByteArray::fromHex("FACCCCAF")) {
                if (frameBuffer.size() == expectedBytes) {
                    framesCount++;
                    totalFramesCompleted++;
                    framesCountForLog++;

                    // =================== C++ 极速解码核心 ===================
                    QImage img;
                    if (m_isRgb565) {
                        img = QImage(m_width, m_height, QImage::Format_RGB16);
                        uint16_t *dest = (uint16_t*)img.bits();
                        uint16_t *src = (uint16_t*)frameBuffer.data();
                        int pixels = m_width * m_height;
                        for(int i = 0; i < pixels; i++) {
                            uint16_t p = src[i];
                            p = (p >> 8) | (p << 8); // 默认 FPGA 发送的是大端，交换为小端
                            if (m_swapBytes) p = (p >> 8) | (p << 8); // 再次交换
                            dest[i] = p;
                        }
                    } else { // RGB888
                        img = QImage((const uchar*)frameBuffer.data(), m_width, m_height, QImage::Format_RGB888).copy();
                        if (m_swapBytes) img = img.rgbSwapped(); // BGR 与 RGB 互换
                    }
                    emit frameReady(img); // 将解码好的图像丢给主 UI 线程
                } else {
                    totalFramesDropped++;
                }
                frameBuffer.clear();
            }
        }
        else if (len > 4 && datagram[0] == (char)0xFA && datagram[len-1] == (char)0xAF) {
            uint8_t h_high = datagram[len-3];
            uint8_t h_low  = datagram[len-2];
            int cnt_h = (h_high << 8) | h_low;

            // 丢包检测与日志写入
            if (last_cnt_h != -1 && cnt_h != last_cnt_h + 1) {
                int dropped = cnt_h - last_cnt_h - 1;
                if (dropped > 0) {
                    totalPacketsDropped += dropped;
                    if (logStream) {
                        QString ts = QDateTime::currentDateTime().toString("HH:mm:ss.zzz");
                        // ⬇️ 完美复刻 Python：去掉了中括号内的空格，恢复了原版的 5, 4, 4, 4 占位宽度
                        *logStream << QString::fromUtf8("[%1] 帧号 %2 | 丢失 %3 包 | 遗漏序号段: [%4 ~ %5]\n")
                                      .arg(ts)
                                      .arg(framesCountForLog + 1, 5)  // 帧号占 5 位
                                      .arg(dropped, 4)                // 丢失包占 4 位
                                      .arg(last_cnt_h + 1, 4)         // 起始包号占 4 位
                                      .arg(cnt_h - 1, 4);             // 结束包号占 4 位
                    }
                }
            }
            last_cnt_h = cnt_h;

            // 提取图像数据拼接
            frameBuffer.append(datagram.constData() + 1, len - 4);
        }
    }
}

// =========================================================
// MainWindow 主界面
// =========================================================
MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent), workerThread(nullptr), worker(nullptr)
{
    setWindowTitle(QString::fromUtf8("派大星 - 以太网视频传输助手"));

    setWindowIcon(QIcon(":/reverbnation_apps_platform_icon_176111.ico"));

    resize(1200, 800);
    setStyleSheet(QSS);
    setupUi();
}

MainWindow::~MainWindow() {
    stopListening();
}

void MainWindow::setupUi() {
    QWidget *mainWidget = new QWidget(this);
    setCentralWidget(mainWidget);
    QHBoxLayout *mainLayout = new QHBoxLayout(mainWidget);
    mainLayout->setContentsMargins(20, 20, 20, 20);
    mainLayout->setSpacing(20);

    // ====== 左侧控制面板 ======
    QWidget *leftPanel = new QWidget();
    leftPanel->setFixedWidth(300);
    QVBoxLayout *leftLayout = new QVBoxLayout(leftPanel);
    leftLayout->setContentsMargins(0, 0, 0, 0);
    leftLayout->setSpacing(15);

    QLabel *titleLabel = new QLabel(QString::fromUtf8("FPGA 视频传输"));
    titleLabel->setFont(QFont("Microsoft YaHei", 20, QFont::Bold));
    titleLabel->setStyleSheet("color: #4A90E2;");
    leftLayout->addWidget(titleLabel);

    // ----------------- IP 地址选择区域 -----------------
    leftLayout->addWidget(new QLabel(QString::fromUtf8("监听 IP 地址:")));

    // 创建一个水平布局，把下拉框和刷新按钮放在同一行
    QWidget *ipWidget = new QWidget();
    QHBoxLayout *ipLayout = new QHBoxLayout(ipWidget);
    ipLayout->setContentsMargins(0, 0, 0, 0);
    ipLayout->setSpacing(10);

    ipCombo = new QComboBox();
    ipCombo->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Fixed); // 让下拉框自动拉伸

    btnRefreshIp = new QPushButton(QString::fromUtf8("🔄 刷新"));
    btnRefreshIp->setToolTip(QString::fromUtf8("重新扫描本地网卡 IP"));
    btnRefreshIp->setStyleSheet("QPushButton { padding: 8px 12px; font-size: 13px; }");
    connect(btnRefreshIp, &QPushButton::clicked, this, &MainWindow::refreshIpList);

    ipLayout->addWidget(ipCombo);
    ipLayout->addWidget(btnRefreshIp);
    leftLayout->addWidget(ipWidget);

    // 启动时自动获取一次 IP
    refreshIpList();
    // ---------------------------------------------------

    leftLayout->addWidget(new QLabel(QString::fromUtf8("监听 端口号:")));
    portInput = new QLineEdit("5678");
    leftLayout->addWidget(portInput);

    leftLayout->addWidget(new QLabel(QString::fromUtf8("水平分辨率 (Width):")));
    widthInput = new QLineEdit("1280");
    leftLayout->addWidget(widthInput);

    leftLayout->addWidget(new QLabel(QString::fromUtf8("垂直分辨率 (Height):")));
    heightInput = new QLineEdit("720");
    leftLayout->addWidget(heightInput);

    swapCheckbox = new QCheckBox(QString::fromUtf8("🔥 翻转字节序 / 通道序"));
    swapCheckbox->setToolTip(QString::fromUtf8("RGB565: 翻转高低字节\nRGB888: R↔B 通道互换"));
    connect(swapCheckbox, &QCheckBox::stateChanged, this, &MainWindow::onSwapChanged);

    QWidget *radioRow = new QWidget();
    QHBoxLayout *radioLayout = new QHBoxLayout(radioRow);
    radioLayout->setContentsMargins(0, 0, 0, 0);
    rgb565Radio = new QRadioButton("RGB565");
    rgb888Radio = new QRadioButton("RGB888");
    rgb565Radio->setChecked(true); // 已修复为小写的 true
    radioLayout->addWidget(rgb565Radio);
    radioLayout->addWidget(rgb888Radio);
    radioLayout->addStretch();
    leftLayout->addWidget(radioRow);
    leftLayout->addWidget(swapCheckbox);

    btnStart = new QPushButton(QString::fromUtf8("▶ 开始监听实时画面"));
    btnStart->setFixedHeight(45);
    connect(btnStart, &QPushButton::clicked, this, &MainWindow::startListening);
    leftLayout->addWidget(btnStart);

    btnStop = new QPushButton(QString::fromUtf8("⏹ 停止监听"));
    btnStop->setFixedHeight(45);
    btnStop->setStyleSheet("QPushButton { background-color: #E74C3C; } QPushButton:hover { background-color: #C0392B; } QPushButton:disabled { background-color: #4D4D4D; }");
    btnStop->setEnabled(false);
    connect(btnStop, &QPushButton::clicked, this, &MainWindow::stopListening);
    leftLayout->addWidget(btnStop);

    statusLabel = new QLabel(QString::fromUtf8("状态: ⚪ 等待启动"));
    statusLabel->setStyleSheet("color: #AAAAAA; margin-top: 20px;");
    statusLabel->setWordWrap(true);
    leftLayout->addWidget(statusLabel);

    fpsLabel = new QLabel(QString::fromUtf8("帧率: 0.00 fps"));
    fpsLabel->setStyleSheet("color: #2ECC71; font-size: 24px; font-weight: bold;");
    leftLayout->addWidget(fpsLabel);

    speedLabel = new QLabel(QString::fromUtf8("速率: 0.00 Mbps"));
    speedLabel->setStyleSheet("color: #3498DB; font-size: 24px; font-weight: bold;");
    leftLayout->addWidget(speedLabel);

    leftLayout->addStretch();
    mainLayout->addWidget(leftPanel);

    // ====== 右侧视频画面 ======
    videoFrame = new QLabel(QString::fromUtf8("等待视频连接..."));
    videoFrame->setAlignment(Qt::AlignCenter);
    videoFrame->setStyleSheet("background-color: qlineargradient(spread:pad, x1:0, y1:0, x2:1, y2:1, stop:0 #3A3A3A, stop:0.5 #4A4A4A, stop:1 #3A3A3A); border: 2px dashed #6A6A6A; border-radius: 10px; font-size: 24px; color: #AAAAAA;");
    videoFrame->setMinimumSize(640, 360);
    mainLayout->addWidget(videoFrame, 1);
}

void MainWindow::startListening() {
    int port = portInput->text().toInt();
    int w = widthInput->text().toInt();
    int h = heightInput->text().toInt();
    QString ip = ipCombo->currentText().split(" ")[0];

    // 初始化工作类和独立线程
    workerThread = new QThread(this);
    worker = new VideoWorker(ip, port, w, h, swapCheckbox->isChecked(), rgb565Radio->isChecked());
    worker->moveToThread(workerThread);

    // 线程启动与停止绑定
    connect(workerThread, &QThread::started, worker, &VideoWorker::startWork);
    connect(worker, &VideoWorker::finished, workerThread, &QThread::quit);
    connect(worker, &VideoWorker::finished, worker, &VideoWorker::deleteLater);
    connect(workerThread, &QThread::finished, workerThread, &QThread::deleteLater);

    // 数据交互绑定
    connect(worker, &VideoWorker::frameReady, this, &MainWindow::updateImage);
    connect(worker, &VideoWorker::statsUpdated, this, &MainWindow::updateStats);
    connect(worker, &VideoWorker::statusUpdated, this, &MainWindow::updateStatus);

    workerThread->start();

    // 更新 UI 状态
    btnStart->setEnabled(false);  btnStop->setEnabled(true);
    ipCombo->setEnabled(false);   portInput->setEnabled(false);
    widthInput->setEnabled(false); heightInput->setEnabled(false);
    rgb565Radio->setEnabled(false); rgb888Radio->setEnabled(false);
    videoFrame->setText(QString::fromUtf8("等待第一帧到达..."));

    // 更新 UI 状态
    btnStart->setEnabled(false);  btnStop->setEnabled(true);
    ipCombo->setEnabled(false);   portInput->setEnabled(false);
    btnRefreshIp->setEnabled(false); // ⬇️ 监听时禁用刷新按钮
    widthInput->setEnabled(false); heightInput->setEnabled(false);
    rgb565Radio->setEnabled(false); rgb888Radio->setEnabled(false);
    videoFrame->setText(QString::fromUtf8("等待第一帧到达..."));
}

void MainWindow::stopListening() {
    if (worker) {
        // 使用 BlockingQueuedConnection 确保底层彻底关闭且日志写入完毕，同时主线程不使用 wait() 避免死锁
        QMetaObject::invokeMethod(worker, "stopWork", Qt::BlockingQueuedConnection);
        worker = nullptr;
        workerThread = nullptr;
    }

    btnStart->setEnabled(true); btnStop->setEnabled(false);
    ipCombo->setEnabled(true); portInput->setEnabled(true);
    btnRefreshIp->setEnabled(true);  // ⬇️ 停止后启用刷新按钮
    widthInput->setEnabled(true); heightInput->setEnabled(true);
    rgb565Radio->setEnabled(true); rgb888Radio->setEnabled(true);

    btnStart->setEnabled(true); btnStop->setEnabled(false);
    ipCombo->setEnabled(true); portInput->setEnabled(true);
    widthInput->setEnabled(true); heightInput->setEnabled(true);
    rgb565Radio->setEnabled(true); rgb888Radio->setEnabled(true);

    statusLabel->setText(QString::fromUtf8("状态: ⚪ 已停止"));
    statusLabel->setStyleSheet("color: #AAAAAA;");
    fpsLabel->setText(QString::fromUtf8("帧率: 0.00 fps"));
    speedLabel->setText(QString::fromUtf8("速率: 0.00 Mbps"));
    videoFrame->setText(QString::fromUtf8("视频流已停止..."));
}

void MainWindow::onSwapChanged(int state) {
    if (worker) {
        QMetaObject::invokeMethod(worker, "setSwap", Q_ARG(bool, state == Qt::Checked));
    }
}

void MainWindow::updateImage(const QImage &img) {
    videoFrame->setPixmap(QPixmap::fromImage(img).scaled(videoFrame->size(), Qt::KeepAspectRatio, Qt::SmoothTransformation));
}

void MainWindow::updateStats(double fps, double speed) {
    fpsLabel->setText(QString::fromUtf8("帧率: %1 fps").arg(fps, 0, 'f', 2));
    speedLabel->setText(QString::fromUtf8("速率: %1 Mbps").arg(speed, 0, 'f', 2));
}

void MainWindow::updateStatus(const QString &msg, bool isError) {
    if (isError) {
        statusLabel->setText(QString::fromUtf8("状态: 🔴 ") + msg);
        statusLabel->setStyleSheet("color: #E74C3C;");
    } else {
        statusLabel->setText(QString::fromUtf8("状态: 🟢 ") + msg);
        statusLabel->setStyleSheet("color: #2ECC71;");
    }
}

// =========================================================
// 刷新本地网卡 IP 列表
// =========================================================
void MainWindow::refreshIpList() {
    ipCombo->clear();
    ipCombo->addItem(QString::fromUtf8("0.0.0.0 (监听所有)"));

    const QHostAddress &localhost = QHostAddress(QHostAddress::LocalHost);
    for (const QHostAddress &address : QNetworkInterface::allAddresses()) {
        // 只筛选 IPv4 并且跳过本地环回地址 (127.0.0.1)
        if (address.protocol() == QAbstractSocket::IPv4Protocol && address != localhost) {
            QString ipStr = address.toString();
            // 防止有重复的 IP 出现
            if (ipCombo->findText(ipStr) == -1) {
                ipCombo->addItem(ipStr);
            }
        }
    }
}
