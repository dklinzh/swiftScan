//
//  LBXScanViewController.swift
//  swiftScan
//
//  Created by lbxia on 15/12/8.
//  Copyright © 2015年 xialibing. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation

public protocol LBXScanViewControllerDelegate: class {
    func scanFinished(scanResult: LBXScanResult, error: String?)
}

public protocol QRRectDelegate {
    func drawwed()
}

open class LBXScanViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    //返回扫码结果，也可以通过继承本控制器，改写该handleCodeResult方法即可
    open weak var scanResultDelegate: LBXScanViewControllerDelegate?
    
    open var delegate: QRRectDelegate?
    
    open lazy var scanObj: LBXScanWrapper = {
        var cropRect = CGRect.zero
        if isOpenInterestRect {
            cropRect = LBXScanView.getScanRectWithPreView(preView: self.view, style: scanStyle)
        }
        
        return LBXScanWrapper(videoPreView: self.view, objType: arrayCodeType, isCaptureImg: isNeedCodeImage, cropRect: cropRect, success: { [weak self] (arrayResult) -> Void in
            guard let strongSelf = self else { return }
            
            //停止扫描动画
            strongSelf.qRScanView.stopScanAnimation()
            
            strongSelf.handleCodeResult(arrayResult: arrayResult)
        })
    }()
    
    open var scanStyle: LBXScanViewStyle = LBXScanViewStyle()
    
    open lazy var qRScanView: LBXScanView = LBXScanView(frame: self.view.frame, vstyle: scanStyle)
    
    //启动区域识别功能
    open var isOpenInterestRect = false
    
    //识别码的类型
    public var arrayCodeType: [AVMetadataObject.ObjectType] = [AVMetadataObject.ObjectType.qr as NSString,
                                                               AVMetadataObject.ObjectType.ean13 as NSString,
                                                               AVMetadataObject.ObjectType.code128 as NSString] as [AVMetadataObject.ObjectType]
    
    //是否需要识别后的当前图像
    public  var isNeedCodeImage = false
    
    //相机启动提示文字
    public var readyString:String! = "loading"
    
    /// 扫描视频镜头是否放大
    private var _isScanVideoZoomIn: Bool = false
    
    private var _videoZoomingTimer: Timer?
    private var _videoZoomFactor: CGFloat = 0.0
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        // [self.view addSubview:_qRScanView];
        self.view.backgroundColor = UIColor.black
        self.edgesForExtendedLayout = UIRectEdge(rawValue: 0)
        
        self.view.isUserInteractionEnabled = true
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(_doubleTapAction(recognizer:)))
        tapRecognizer.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(tapRecognizer)
        
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(_pinchAction(recognizer:)))
        self.view.addGestureRecognizer(pinchRecognizer)
        
        NotificationCenter.default.addObserver(self, selector: #selector(_observeAVCaptureSession(notification:)), name: .AVCaptureSessionDidStartRunning, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(_observeAVCaptureSession(notification:)), name: .AVCaptureSessionDidStopRunning, object: nil)
    }
    
    @objc private func _observeAVCaptureSession(notification: Notification) {
        switch notification.name {
        case .AVCaptureSessionDidStartRunning:
            if !_isScanVideoZoomIn {
                _videoZoomingTimer = Timer.scheduledTimer(timeInterval: scanStyle.animationPeriod, target: self, selector: #selector(_scanVideoZoomIn), userInfo: nil, repeats: true)
            }
            break
        case .AVCaptureSessionDidStopRunning:
            _videoZoomingTimer?.invalidate()
            break
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
    
    open func setNeedCodeImage(needCodeImg:Bool)
    {
        isNeedCodeImage = needCodeImg;
    }
    //设置框内识别
    open func setOpenInterestRect(isOpen:Bool){
        isOpenInterestRect = isOpen
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.addSubview(qRScanView)
        delegate?.drawwed()
        
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.startScan()
        }
        //        perform(#selector(LBXScanViewController.startScan), with: nil, afterDelay: 0.3)
    }
    
    open func startScan() {
        //结束相机等待提示
        qRScanView.deviceStopReadying()
        
        //开始扫描动画
        qRScanView.startScanAnimation()
        
        //相机运行
        scanObj.start()
    }
    
    /**
     处理扫码结果，如果是继承本控制器的，可以重写该方法,作出相应地处理，或者设置delegate作出相应处理
     */
    open func handleCodeResult(arrayResult:[LBXScanResult])
    {
        if let delegate = scanResultDelegate  {
            
            self.navigationController? .popViewController(animated: true)
            let result:LBXScanResult = arrayResult[0]
            
            delegate.scanFinished(scanResult: result, error: nil)
            
        }else{
            
            for result:LBXScanResult in arrayResult
            {
                print("%@",result.strScanned ?? "")
            }
            
            let result:LBXScanResult = arrayResult[0]
            
            showMsg(title: result.strBarCodeType, message: result.strScanned)
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        qRScanView.stopScanAnimation()
        
        scanObj.stop()
    }
    
    open func openPhotoAlbum()
    {
        LBXPermissions.authorizePhotoWith { [weak self] (granted) in
            
            let picker = UIImagePickerController()
            
            picker.sourceType = UIImagePickerController.SourceType.photoLibrary
            
            picker.delegate = self;
            
            picker.allowsEditing = true
            
            self?.present(picker, animated: true, completion: nil)
        }
    }
    
    //MARK: -----相册选择图片识别二维码 （条形码没有找到系统方法）
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any])
    {
        picker.dismiss(animated: true, completion: nil)
        
        var image:UIImage? = info[UIImagePickerController.InfoKey.editedImage.rawValue] as? UIImage
        
        if (image == nil )
        {
            image = info[UIImagePickerController.InfoKey.originalImage.rawValue] as? UIImage
        }
        
        if(image != nil)
        {
            let arrayResult = LBXScanWrapper.recognizeQRImage(image: image!)
            if arrayResult.count > 0
            {
                handleCodeResult(arrayResult: arrayResult)
                return
            }
        }
        
        showMsg(title: nil, message: NSLocalizedString("Identify failed", comment: "Identify failed"))
    }
    
    func showMsg(title:String?,message:String?)
    {
        
        let alertController = UIAlertController(title: nil, message:message, preferredStyle: UIAlertController.Style.alert)
        let alertAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: UIAlertAction.Style.default) { (alertAction) in
            
            //                if let strongSelf = self
            //                {
            //                    strongSelf.startScan()
            //                }
        }
        
        alertController.addAction(alertAction)
        present(alertController, animated: true, completion: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
