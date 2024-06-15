//
//  BottomSheetController.swift
//
//
//  Created by Naruki Chigira on 2021/06/06.
//

import UIKit

/// Component containing supplementary content that are anchored to the bottom of the screen.
public class BottomSheetController: UIViewController {
    /// Open Animation Duration.
    private let openAnimationDuration: TimeInterval = 0.3
    /// Open Animation Spring with Damping
    private let openAnimationSpringWithDamping: CGFloat = 1.0
    /// Close Animation Duration.
    private let closeAnimationDuration: TimeInterval = 0.2
    /// Threshould value to decide closing sheet or not when pan gesture ended.
    private let thresholdVelocityToClose: CGFloat = 500.0
    /// Factor of content transition caused by pan gesture.
    private let contentTransitionFactor: CGFloat = 0.8
    /// Factor of over content transition caused by pan gesture.
    private let overContentTransitionFactor: CGFloat = 0.1

    @IBOutlet private var background: UIView!
    @IBOutlet private var sheet: UIView!
    @IBOutlet private var roundedHeader: UIView! {
        didSet {
            configureRoundedHeader()
        }
    }
    @IBOutlet private var intermediate: UIView!
    @IBOutlet private var bottomFiller: UIView!
    @IBOutlet private var container: UIView!
    @IBOutlet private var position: NSLayoutConstraint!
    @IBOutlet weak var sheetBottomConstraint: NSLayoutConstraint!
    
    /// Background color of sheet's background.
    public var backgroundColor: UIColor = .init(white: 0, alpha: 0.5) {
        didSet {
            updateBackgroundColor()
        }
    }

    /// Background color of sheet.
    public var contentBackgroundColor: UIColor = .white {
        didSet {
            updateContentBackgroundColor()
        }
    }

    public var adaptsToKeyboard = true
    
    private var transition: CGFloat = 0
    private var sheetHeight: CGFloat = 0
    private let contentView: UIView
    private let contentViewController: UIViewController?

    /// Create new bottom sheet.
    ///
    /// Size of contentViewController's view must be fixed or decided by contents contained itself.
    ///
    /// - parameters:
    ///   - contentViewController: ViewController for embeded content.
    public init(contentViewController: UIViewController) {
        contentView = contentViewController.view
        self.contentViewController = contentViewController
        super.init(nibName: "BottomSheetController", bundle: Bundle.module)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    /// Create new bottom sheet.
    ///
    /// Size of contentView must be fixed or decided by contents contained itself.
    ///
    /// - parameters:
    ///   - contentView: View for embeded content.
    public init(contentView: UIView) {
        self.contentView = contentView
        self.contentViewController = nil
        super.init(nibName: "BottomSheetController", bundle: Bundle.module)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Attach content view on container
        if let contentViewController = contentViewController {
            addChild(contentViewController)
        }
        container.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        container.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        container.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
        container.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
        if let contentViewController = contentViewController {
            contentViewController.didMove(toParent: self)
        }
        
        observeKeyboardNotifications()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sheetHeight = sheet.frame.height
        closeSheet(animated: false)
        DispatchQueue.main.async {
            self.openSheet(animated: true)
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureRoundedHeader()
    }

    /// Close sheet programmatically.
    func close(completion: (() -> Void)? = nil) {
        sheetHeight = sheet.frame.height
        closeSheet(animated: true) { _ in
            self.dismiss(animated: true)
        }
    }

    private func configureRoundedHeader() {
        let path = UIBezierPath(
            roundedRect: roundedHeader.bounds,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: 16, height: 16)
        )
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        roundedHeader.layer.mask = mask
    }

    private func updateBackgroundColor() {
        loadViewIfNeeded()
        background.backgroundColor = backgroundColor
    }

    private func updateContentBackgroundColor() {
        loadViewIfNeeded()
        roundedHeader.backgroundColor = contentBackgroundColor
        intermediate.backgroundColor = contentBackgroundColor
        bottomFiller.backgroundColor = contentBackgroundColor
    }

    private func openSheet(animated: Bool) {
        if animated {
            position.constant = 0
            UIView.animate(
                withDuration: openAnimationDuration,
                delay: 0,
                usingSpringWithDamping: openAnimationSpringWithDamping,
                initialSpringVelocity: 1,
                options: [.curveEaseInOut],
                animations: {
                    self.background.alpha = 1.0
                    self.view.layoutIfNeeded()
                }
            ) { _ in }
        } else {
            background.alpha = 1.0
            position.constant = 0
            view.layoutIfNeeded()
        }
    }

    private func closeSheet(animated: Bool, completion: ((Bool) -> ())? = nil) {
        if animated {
            position.constant = -sheetHeight
            UIView.animate(
                withDuration: closeAnimationDuration,
                animations: {
                    self.background.alpha = 0.0
                    self.view.layoutIfNeeded()
                },
                completion: { completed in
                    completion?(completed)
                }
            )
        } else {
            background.alpha = 0.0
            position.constant = -sheetHeight
            view.layoutIfNeeded()
            completion?(true)
        }
    }

    private func observeKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc
    private func keyboardWillShow(_ notification: Notification) {
        guard adaptsToKeyboard,
              let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        
        sheetBottomConstraint.constant = keyboardFrame.size.height
        UIView.animate(withDuration: animationDuration, delay: 0, options: UIView.AnimationOptions(rawValue: animationCurve << 16)) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }
    
    @objc
    private func keyboardWillHide(_ notification: Notification) {
        guard adaptsToKeyboard,
              let userInfo = notification.userInfo else { return }
        
        let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        
        sheetBottomConstraint.constant = 0
        UIView.animate(withDuration: animationDuration, delay: 0, options: UIView.AnimationOptions(rawValue: animationCurve << 16)) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }
    
    @IBAction private func didPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            sheetHeight = sheet.frame.height
        case .changed:
            let translation: CGFloat = gestureRecognizer.translation(in: view).y
            let factor: CGFloat = position.constant > 0 ? overContentTransitionFactor : contentTransitionFactor
            transition -= translation * factor
            if 0..<view.safeAreaInsets.bottom ~= transition {
                if translation < 0 {
                    transition = view.safeAreaInsets.bottom
                } else {
                    transition = 0
                }
            }
            position.constant = transition
            gestureRecognizer.setTranslation(.zero, in: view)
        case .ended:
            let velocity = gestureRecognizer.velocity(in: view).y
            if velocity > thresholdVelocityToClose || transition < -(sheetHeight * 0.5) {
                closeSheet(animated: true) { _ in
                    self.dismiss(animated: true)
                }
            } else {
                openSheet(animated: true)
            }
            transition = 0
            gestureRecognizer.setTranslation(.zero, in: view)
        default:
            break
        }
    }

    @IBAction private func didTapBackground(_ gestureRecognizer: UITapGestureRecognizer) {
        close()
    }
}
