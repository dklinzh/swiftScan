//
//  LBXScanViewController.swift
//  swiftScan
//
//  Created by lbxia on 15/12/8.
//  Copyright © 2015年 xialibing. All rights reserved.
//

import AVFoundation
import Foundation
import UIKit

public protocol LBXScanViewControllerDelegate: class {
    func scanFinished(scanResult: LBXScanResult, error: String?)
}

public protocol QRRectDelegate {
    func drawwed()
}

open class LBXScanViewController: UIViewController {
    // 返回扫码结果，也可以通过继承本控制器，改写该handleCodeResult方法即可
    open weak var scanResultDelegate: LBXScanViewControllerDelegate?

    open var delegate: QRRectDelegate?

    open lazy var scanObj: LBXScanWrapper = {
        var cropRect = CGRect.zero
        if isOpenInterestRect {
            cropRect = LBXScanView.getScanRectWithPreView(preView: self.view, style: scanStyle)
        }

        return LBXScanWrapper(videoPreView: self.view, objType: arrayCodeType, isCaptureImg: isNeedCodeImage, cropRect: cropRect, success: { [weak self] (arrayResult) -> Void in
            guard let strongSelf = self else { return }

            // 停止扫描动画
            strongSelf.qRScanView.stopScanAnimation()

            strongSelf.handleCodeResult(arrayResult: arrayResult)
        })
    }()

    open var scanStyle: LBXScanViewStyle = LBXScanViewStyle()

    open lazy var qRScanView: LBXScanView = LBXScanView(frame: self.view.frame, vstyle: scanStyle)

    // 启动区域识别功能
    open var isOpenInterestRect = false

    // 识别码的类型
    public var arrayCodeType: [AVMetadataObject.ObjectType] = [AVMetadataObject.ObjectType.qr as NSString,
                                                               AVMetadataObject.ObjectType.ean13 as NSString,
                                                               AVMetadataObject.ObjectType.code128 as NSString] as [AVMetadataObject.ObjectType]

    // 是否需要识别后的当前图像
    public var isNeedCodeImage = false

    // 相机启动提示文字
    public var readyString: String! = "loading"

    /// 扫描视频镜头是否放大
    private var _isScanVideoZoomIn: Bool = false

    private var _videoZoomingTimer: Timer?
    private var _videoZoomFactor: CGFloat = 0.0

    open override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        // [self.view addSubview:_qRScanView];
        view.backgroundColor = UIColor.black
        edgesForExtendedLayout = UIRectEdge(rawValue: 0)

        view.isUserInteractionEnabled = true
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(_doubleTapAction(recognizer:)))
        tapRecognizer.numberOfTapsRequired = 2
        view.addGestureRecognizer(tapRecognizer)

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(_pinchAction(recognizer:)))
        view.addGestureRecognizer(pinchRecognizer)

        NotificationCenter.default.addObserver(self, selector: #selector(_observeAVCaptureSession(notification:)), name: .AVCaptureSessionDidStartRunning, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(_observeAVCaptureSession(notification:)), name: .AVCaptureSessionDidStopRunning, object: nil)
    }

    @objc private func _observeAVCaptureSession(notification: Notification) {
        switch notification.name {
        case .AVCaptureSessionDidStartRunning:
            if !_isScanVideoZoomIn {
                _videoZoomingTimer = Timer.scheduledTimer(timeInterval: scanStyle.animationPeriod, target: self, selector: #selector(_scanVideoZoomIn), userInfo: nil, repeats: true)
            }
        case .AVCaptureSessionDidStopRunning:
            _videoZoomingTimer?.invalidate()
        default:
            break
        }
    }

    @objc private func _scanVideoZoomIn() {
        if !_isScanVideoZoomIn {
            _videoZoomFactor += 2.0
            scanObj.setVideoZoom(zoomFactor: _videoZoomFactor, transitionRate: 2.0)

            _isScanVideoZoomIn = scanObj.isVideoZoomIn
            if _isScanVideoZoomIn {
                _videoZoomingTimer?.invalidate()
            }
        } else {
            _videoZoomingTimer?.invalidate()
        }
    }

    @objc private func _doubleTapAction(recognizer: UITapGestureRecognizer) {
        _isScanVideoZoomIn = !_isScanVideoZoomIn
        scanObj.isVideoZoomIn = _isScanVideoZoomIn

        _videoZoomingTimer?.invalidate()
    }

    @objc private func _pinchAction(recognizer: UIPinchGestureRecognizer) {
        let state = recognizer.state
        let isfinished = (state == .ended) || (state == .cancelled) || (state == .failed)
        scanObj.setVideoZoom(pinchScale: recognizer.scale, isfinished: isfinished)
        _isScanVideoZoomIn = scanObj.isVideoZoomIn

        _videoZoomingTimer?.invalidate()
    }

    open func setNeedCodeImage(needCodeImg: Bool) {
        isNeedCodeImage = needCodeImg
    }

    // 设置框内识别
    open func setOpenInterestRect(isOpen: Bool) {
        isOpenInterestRect = isOpen
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        view.addSubview(qRScanView)
        delegate?.drawwed()
//        qRScanView.deviceStartReadying(readyStr: readyString)

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.startScan()
        }
    }

    open func startScan() {
        // 结束相机等待提示
        qRScanView.deviceStopReadying()

        // 开始扫描动画
        qRScanView.startScanAnimation()

        // 相机运行
        scanObj.start()
    }

    /**
     处理扫码结果，如果是继承本控制器的，可以重写该方法,作出相应地处理，或者设置delegate作出相应处理
     */
    open func handleCodeResult(arrayResult: [LBXScanResult]) {
        guard let delegate = scanResultDelegate else {
            fatalError("you must set scanResultDelegate or override this method without super keyword")
        }
        navigationController?.popViewController(animated: true)
        if let result = arrayResult.first {
            delegate.scanFinished(scanResult: result, error: nil)
        } else {
            let result = LBXScanResult(str: nil, img: nil, barCodeType: nil, corner: nil)
            delegate.scanFinished(scanResult: result, error: "no scan result")
        }
    }

    open override func viewWillDisappear(_ animated: Bool) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)

        qRScanView.stopScanAnimation()

        scanObj.stop()
    }

    @objc open func openPhotoAlbum() {
        LBXPermissions.authorizePhotoWith { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = UIImagePickerController.SourceType.photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true, completion: nil)
        }
    }
}

// MARK: - 图片选择代理方法

extension LBXScanViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // MARK: -----相册选择图片识别二维码 （条形码没有找到系统方法）

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)

        let editedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage
        let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
        guard let image = editedImage ?? originalImage else {
            showMsg(title: nil, message: NSLocalizedString("Identify failed", comment: "Identify failed"))
            return
        }
        let arrayResult = LBXScanWrapper.recognizeQRImage(image: image)
        if !arrayResult.isEmpty {
            handleCodeResult(arrayResult: arrayResult)
        }
    }
}

// MARK: - 私有方法

private extension LBXScanViewController {
    func showMsg(title: String?, message: String?) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil)
        alertController.addAction(alertAction)
        present(alertController, animated: true, completion: nil)
    }
}
