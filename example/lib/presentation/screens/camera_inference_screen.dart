// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 添加觸覺回饋支援
import 'package:ultralytics_yolo/yolo_result.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart'; // 添加液態玻璃效果
import '../../models/model_type.dart';
import '../../models/slider_type.dart';
import '../../services/model_manager.dart';
import 'webview_screen.dart'; // 導入 WebView 頁面

/// A screen that demonstrates real-time YOLO inference using the device camera.
///
/// This screen provides:
/// - Live camera feed with YOLO object detection
/// - Adjustable thresholds (confidence, IoU, max detections)
/// - Camera controls (flip, zoom)
/// - Performance metrics (FPS)
class CameraInferenceScreen extends StatefulWidget {
  const CameraInferenceScreen({super.key});

  @override
  State<CameraInferenceScreen> createState() => _CameraInferenceScreenState();
}

class _CameraInferenceScreenState extends State<CameraInferenceScreen>
    with TickerProviderStateMixin {
  int _detectionCount = 0;
  double _confidenceThreshold = 0.5;
  double _iouThreshold = 0.45;
  int _numItemsThreshold = 30;
  double _currentFps = 0.0;
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();

  SliderType _activeSlider = SliderType.none;
  bool _isModelLoading = false;
  String? _modelPath;
  String _loadingMessage = '';
  double _downloadProgress = 0.0;

  final _yoloController = YOLOViewController();
  final _yoloViewKey = GlobalKey<YOLOViewState>();
  final bool _useController = true;

  late final ModelManager _modelManager;
  
  // 新增：按鈕動畫控制器
  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;
  bool _isButtonPressed = false;
  
  // 新增：donkey 偵測狀態
  bool _hasDonkeyDetected = false;
  List<YOLOResult> _currentDetections = [];
  
  // 新增：identification 狀態和最高機率 donkey 資訊
  bool _isIdentificationPressed = false;
  String? _topDonkeyName;
  double _topDonkeyConfidence = 0.0;

  @override
  void initState() {
    super.initState();

    // Initialize ModelManager
    _modelManager = ModelManager(
      onDownloadProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      },
      onStatusUpdate: (message) {
        if (mounted) {
          setState(() {
            _loadingMessage = message;
          });
        }
      },
    );

    // Load initial model
    _loadModelForPlatform();

    // Set initial thresholds after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_useController) {
        _yoloController.setThresholds(
          confidenceThreshold: _confidenceThreshold,
          iouThreshold: _iouThreshold,
          numItemsThreshold: _numItemsThreshold,
        );
      } else {
        _yoloViewKey.currentState?.setThresholds(
          confidenceThreshold: _confidenceThreshold,
          iouThreshold: _iouThreshold,
          numItemsThreshold: _numItemsThreshold,
        );
      }
    });

    // 初始化按鈕動畫控制器
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _buttonAnimationController.dispose();
    super.dispose();
  }

  /// Called when new detection results are available
  ///
  /// Updates the UI with:
  /// - Number of detections
  /// - FPS calculation
  /// - Debug information for first few detections
  void _onDetectionResults(List<YOLOResult> results) {
    if (!mounted) return;

    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastFpsUpdate).inMilliseconds;

    if (elapsed >= 1000) {
      final calculatedFps = _frameCount * 1000 / elapsed;
      debugPrint('Calculated FPS: ${calculatedFps.toStringAsFixed(1)}');

      _currentFps = calculatedFps;
      _frameCount = 0;
      _lastFpsUpdate = now;
    }

    // 更新偵測結果和 donkey 狀態
    setState(() {
      _detectionCount = results.length;
      _currentDetections = results;
      
      // 檢查是否有 donkey 被偵測到
      _hasDonkeyDetected = results.any((result) => 
        result.className.toLowerCase().contains('donkey') ||
        result.className.toLowerCase().contains('horse') // 有些模型可能將 donkey 分類為 horse
      );
      
      // 找出最高機率的 donkey
      if (_hasDonkeyDetected) {
        var donkeyResults = results.where((result) => 
          result.className.toLowerCase().contains('donkey') ||
          result.className.toLowerCase().contains('horse')
        ).toList();
        
        if (donkeyResults.isNotEmpty) {
          // 按信心度排序，取最高機率的
          donkeyResults.sort((a, b) => b.confidence.compareTo(a.confidence));
          _topDonkeyName = donkeyResults.first.className;
          _topDonkeyConfidence = donkeyResults.first.confidence;
        }
      } else {
        _topDonkeyName = null;
        _topDonkeyConfidence = 0.0;
      }
    });

    // Debug first few detections
    for (var i = 0; i < results.length && i < 3; i++) {
      final r = results[i];
      debugPrint(
        'Detection $i: ${r.className} (${(r.confidence * 100).toStringAsFixed(1)}%) at ${r.boundingBox}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // YOLO View: must be at back
          if (_modelPath != null && !_isModelLoading)
            YOLOView(
              key: _useController
                  ? const ValueKey('yolo_view_static')
                  : _yoloViewKey,
              controller: _useController ? _yoloController : null,
              modelPath: _modelPath!,
              task: ModelType.detect.task,
              onResult: _onDetectionResults,
              onPerformanceMetrics: (metrics) {
                if (mounted) {
                  setState(() {
                    _currentFps = metrics.fps;
                  });
                }
              },
            )
          else if (_isModelLoading)
            IgnorePointer(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ultralytics logo
                      Image.asset(
                        'assets/logo.png',
                        width: 120,
                        height: 120,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 32),
                      // Loading message
                      Text(
                        _loadingMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Progress indicator
                      if (_downloadProgress > 0)
                        Column(
                          children: [
                            SizedBox(
                              width: 200,
                              child: LinearProgressIndicator(
                                value: _downloadProgress,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${(_downloadProgress * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      else
                        const CircularProgressIndicator(color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),

          // Top info pills (detection, FPS, and current threshold)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16, // Safe area + spacing
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ask Elvis 標題
                Text(
                  'Ask Elvis',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(2.0, 2.0),
                        blurRadius: 4.0,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 檢測數量和FPS顯示
                IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'DETECTIONS: ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$_detectionCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'FPS: ${_currentFps.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_activeSlider == SliderType.confidence)
                  _buildTopPill(
                    'CONFIDENCE THRESHOLD: ${_confidenceThreshold.toStringAsFixed(2)}',
                  ),
                if (_activeSlider == SliderType.iou)
                  _buildTopPill(
                    'IOU THRESHOLD: ${_iouThreshold.toStringAsFixed(2)}',
                  ),
                if (_activeSlider == SliderType.numItems)
                  _buildTopPill('ITEMS MAX: $_numItemsThreshold'),
              ],
            ),
          ),

          // Identification 玻璃按鈕 - 放置在螢幕中下方，方便大拇指操作
          if (_modelPath != null && !_isModelLoading)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 100, // 距離底部 100px，加上安全區域
              child: Align(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTapDown: (_) {
                    if (_hasDonkeyDetected) {
                      setState(() {
                        _isButtonPressed = true;
                      });
                      _buttonAnimationController.forward();
                      // 添加觸覺回饋
                      HapticFeedback.lightImpact();
                    }
                  },
                  onTapUp: (_) {
                    if (_hasDonkeyDetected) {
                      setState(() {
                        _isButtonPressed = false;
                        _isIdentificationPressed = true;
                      });
                      _buttonAnimationController.reverse();
                      // 添加觸覺回饋
                      HapticFeedback.mediumImpact();
                      // TODO: 處理 Identification 按鈕點擊事件
                      debugPrint('Identification button tapped');
                    }
                  },
                  onTapCancel: () {
                    if (_hasDonkeyDetected) {
                      setState(() {
                        _isButtonPressed = false;
                      });
                      _buttonAnimationController.reverse();
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _buttonScaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _hasDonkeyDetected ? _buttonScaleAnimation.value : 1.0,
                        child: LiquidGlass(
                          shape: LiquidRoundedSuperellipse(
                            borderRadius: const Radius.circular(40),
                          ),
                          child: Container(
                            width: 200, // 橫向橢圓形，寬度較大
                            height: 80, // 高度較小，形成橢圓形
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40), // 圓角等於高度的一半
                              color: _hasDonkeyDetected 
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.03), // 反灰時更透明
                              border: Border.all(
                                color: _hasDonkeyDetected 
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.3), // 反灰時邊框更淡
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _hasDonkeyDetected 
                                    ? Colors.black54
                                    : Colors.black26, // 反灰時陰影更淡
                                  blurRadius: 32,
                                  offset: const Offset(0, 16),
                                ),
                                if (_isButtonPressed && _hasDonkeyDetected)
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _hasDonkeyDetected ? 'Identification' : 'Please point to a donkey',
                                style: TextStyle(
                                  color: _hasDonkeyDetected 
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.6), // 反灰時文字更淡
                                  fontSize: _hasDonkeyDetected ? 18 : 14, // 反灰時字體更小，確保一行顯示
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8, // 減少字母間距，節省空間
                                ),
                                textAlign: TextAlign.center, // 確保文字居中
                                maxLines: 1, // 強制一行顯示
                                overflow: TextOverflow.ellipsis, // 如果還是太長，顯示省略號
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // The Donkey Sanctuary 網站導航按鈕 - 底部右側
          if (_modelPath != null && !_isModelLoading)
            Positioned(
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
              child: GestureDetector(
                onTap: () {
                  // 添加觸覺回饋
                  HapticFeedback.selectionClick();
                  
                  if (_isIdentificationPressed && _topDonkeyName != null) {
                    // 顯示特定 donkey 的網頁
                    debugPrint('Opening specific donkey page for: $_topDonkeyName (${(_topDonkeyConfidence * 100).toStringAsFixed(1)}%)');
                    // 開啟 WebView 顯示特定 donkey 的網頁
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WebViewScreen(
                          url: 'https://www.thedonkeysanctuary.org.uk/donkeys/${_topDonkeyName?.toLowerCase().replaceAll(' ', '-')}',
                          title: '$_topDonkeyName Information',
                        ),
                      ),
                    );
                  } else {
                    // 顯示 Donkey Sanctuary 首頁
                    debugPrint('Opening The Donkey Sanctuary homepage');
                    // 開啟 WebView 顯示 Donkey Sanctuary 首頁
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WebViewScreen(
                          url: 'https://www.thedonkeysanctuary.org.uk',
                          title: 'The Donkey Sanctuary',
                        ),
                      ),
                    );
                  }
                },
                child: LiquidGlass(
                  shape: LiquidRoundedSuperellipse(
                    borderRadius: const Radius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 縮小內邊距
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20), // 縮小圓角
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.language, // 改為地球圖標
                          color: Colors.white,
                          size: 16, // 縮小圖標
                        ),
                        const SizedBox(width: 6), // 縮小間距
                        Text(
                          _isIdentificationPressed && _topDonkeyName != null
                              ? '${_topDonkeyName} (${(_topDonkeyConfidence * 100).toStringAsFixed(0)}%)'
                              : 'Donkey Sanctuary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _isIdentificationPressed && _topDonkeyName != null ? 10 : 12, // 縮小字體
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom slider overlay
          if (_activeSlider != SliderType.none)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                color: Colors.black.withValues(alpha: 0.8),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.yellow,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                    thumbColor: Colors.yellow,
                    overlayColor: Colors.yellow.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _getSliderValue(),
                    min: _getSliderMin(),
                    max: _getSliderMax(),
                    divisions: _getSliderDivisions(),
                    label: _getSliderLabel(),
                    onChanged: (value) {
                      setState(() {
                        _updateSliderValue(value);
                      });
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a pill-shaped container with text
  ///
  /// [label] is the text to display in the pill
  Widget _buildTopPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.all(Radius.circular(24)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Gets the current value for the active slider
  double _getSliderValue() {
    switch (_activeSlider) {
      case SliderType.numItems:
        return _numItemsThreshold.toDouble();
      case SliderType.confidence:
        return _confidenceThreshold;
      case SliderType.iou:
        return _iouThreshold;
      default:
        return 0.0;
    }
  }

  /// Gets the minimum value for the active slider
  double _getSliderMin() => _activeSlider == SliderType.numItems ? 5 : 0.1;

  /// Gets the maximum value for the active slider
  double _getSliderMax() => _activeSlider == SliderType.numItems ? 50 : 0.9;

  /// Gets the number of divisions for the active slider
  int _getSliderDivisions() => _activeSlider == SliderType.numItems ? 9 : 8;

  /// Gets the label text for the active slider
  String _getSliderLabel() {
    switch (_activeSlider) {
      case SliderType.numItems:
        return '$_numItemsThreshold';
      case SliderType.confidence:
        return _confidenceThreshold.toStringAsFixed(1);
      case SliderType.iou:
        return _iouThreshold.toStringAsFixed(1);
      default:
        return '';
    }
  }

  /// Updates the value of the active slider
  ///
  /// This method updates both the UI state and the YOLO view controller
  /// with the new threshold value.
  void _updateSliderValue(double value) {
    switch (_activeSlider) {
      case SliderType.numItems:
        _numItemsThreshold = value.toInt();
        if (_useController) {
          _yoloController.setNumItemsThreshold(_numItemsThreshold);
        } else {
          _yoloViewKey.currentState?.setNumItemsThreshold(_numItemsThreshold);
        }
        break;
      case SliderType.confidence:
        _confidenceThreshold = value;
        if (_useController) {
          _yoloController.setConfidenceThreshold(value);
        } else {
          _yoloViewKey.currentState?.setConfidenceThreshold(value);
        }
        break;
      case SliderType.iou:
        _iouThreshold = value;
        if (_useController) {
          _yoloController.setIoUThreshold(value);
        } else {
          _yoloViewKey.currentState?.setIoUThreshold(value);
        }
        break;
      default:
        break;
    }
  }

  Future<void> _loadModelForPlatform() async {
    setState(() {
      _isModelLoading = true;
      _loadingMessage = 'Loading model...';
      _downloadProgress = 0.0;
      // Reset metrics when switching models
      _detectionCount = 0;
      _currentFps = 0.0;
      _frameCount = 0;
      _lastFpsUpdate = DateTime.now();
    });

    try {
      // Use ModelManager to get the model path
      // This will automatically download if not found locally
      final modelPath = await _modelManager.getModelPath(ModelType.detect);

      if (mounted) {
        setState(() {
          _modelPath = modelPath;
          _isModelLoading = false;
          _loadingMessage = '';
          _downloadProgress = 0.0;
        });

        if (modelPath != null) {
          debugPrint('CameraInferenceScreen: Model path set to: $modelPath');
        } else {
          // Model loading failed
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Model Not Available'),
              content: Text(
                'Failed to load model. Please check your internet connection and try again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading model: $e');
      if (mounted) {
        setState(() {
          _isModelLoading = false;
          _loadingMessage = 'Failed to load model';
          _downloadProgress = 0.0;
        });
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Model Loading Error'),
            content: Text(
              'Failed to load model: ${e.toString()}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}
