#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QUdpSocket>
#include <QThread>
#include <QLabel>
#include <QLineEdit>
#include <QComboBox>
#include <QPushButton>
#include <QCheckBox>
#include <QRadioButton>
#include <QButtonGroup>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QElapsedTimer>
#include <QHostInfo>
#include <QTimer>

#include <QFile>
#include <QTextStream>
#include <QDateTime>

// ==========================================
// 工作线程类：负责底层网络接收和图像解码
// ==========================================
class VideoWorker : public QObject {
    Q_OBJECT
public:
    VideoWorker(QString ip, quint16 port, int w, int h, bool swap, bool isRgb565);
    ~VideoWorker();

public slots:
    void startWork();
    void stopWork();
    void setSwap(bool swap);

private slots:
    void readPendingDatagrams();
    void calculateStats();

signals:
    void frameReady(QImage img);
    void statsUpdated(double fps, double speed);
    void statusUpdated(QString msg, bool isError);
    void finished();

private:
    QUdpSocket *udpSocket;
    QString m_ip;
    quint16 m_port;
    int m_width, m_height;
    bool m_swapBytes, m_isRgb565;

    QByteArray frameBuffer;
    int expectedBytes;
    int last_cnt_h;

    // 统计参数
    uint64_t bytesReceivedForSpeed;
    int framesCount;
    QElapsedTimer fpsTimer;
    QTimer *statsTimer;

    // ⬇️ 新增的日志与全局统计变量 ⬇️
    QFile *logFile;
    QTextStream *logStream;

    uint64_t totalPacketsReceived;
    uint64_t totalPacketsDropped;
    uint64_t totalFramesCompleted;
    uint64_t totalFramesDropped;
    uint64_t totalBytesReceivedAll;
    qint64 sessionStartTime;
    int framesCountForLog;
};

// ==========================================
// 主窗口类：负责 UI 显示
// ==========================================
class MainWindow : public QMainWindow {
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private slots:
    void startListening();
    void stopListening();
    void updateImage(const QImage &img);
    void updateStats(double fps, double speed);
    void updateStatus(const QString &msg, bool isError);
    void onSwapChanged(int state);

    // ⬇️ 新增：刷新 IP 列表的槽函数
    void refreshIpList();

private:
    void setupUi();

    // UI 控件
    QComboBox *ipCombo;
    QLineEdit *portInput, *widthInput, *heightInput;
    QCheckBox *swapCheckbox;
    QRadioButton *rgb565Radio, *rgb888Radio;
    QPushButton *btnStart, *btnStop;

    // ⬇️ 新增：刷新按钮指针
    QPushButton *btnRefreshIp;
    QLabel *statusLabel, *fpsLabel, *speedLabel, *videoFrame;

    QThread *workerThread;
    VideoWorker *worker;
};

#endif // MAINWINDOW_H
