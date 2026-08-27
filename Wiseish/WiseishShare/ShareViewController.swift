import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let doneButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        collectSharedContent()
    }

    private func configureView() {
        view.backgroundColor = UIColor(red: 0.96, green: 0.92, blue: 0.85, alpha: 1)

        titleLabel.text = "Ishに食べさせる"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.16, green: 0.15, blue: 0.13, alpha: 1)

        statusLabel.text = "ながめています…"
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = UIColor(red: 0.44, green: 0.41, blue: 0.37, alpha: 1)
        statusLabel.numberOfLines = 0

        var configuration = UIButton.Configuration.filled()
        configuration.title = "できた"
        configuration.baseBackgroundColor = UIColor(red: 0.85, green: 0.66, blue: 0.23, alpha: 1)
        configuration.baseForegroundColor = UIColor(red: 0.16, green: 0.15, blue: 0.13, alpha: 1)
        configuration.cornerStyle = .large
        doneButton.configuration = configuration
        doneButton.isEnabled = false
        doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, statusLabel, doneButton])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            doneButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func collectSharedContent() {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        var fragments = items.compactMap { $0.attributedContentText?.string }
        var images: [UIImage] = []
        let group = DispatchGroup()
        let lock = NSLock()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                    if let text = item as? String {
                        lock.lock(); fragments.append(text); lock.unlock()
                    }
                    group.leave()
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                    if let url = item as? URL {
                        lock.lock(); fragments.append(url.absoluteString); lock.unlock()
                    }
                    group.leave()
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.image.identifier) { item, _ in
                    let image: UIImage?
                    if let loadedImage = item as? UIImage {
                        image = loadedImage
                    } else if let url = item as? URL {
                        image = UIImage(contentsOfFile: url.path)
                    } else if let data = item as? Data {
                        image = UIImage(data: data)
                    } else {
                        image = nil
                    }
                    if let image {
                        lock.lock(); images.append(image); lock.unlock()
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            DispatchQueue.main.async {
                self?.statusLabel.text = "もぐもぐ。\n受け取りました。\n今日の一枚は、そのまま置いておきます。"
                self?.doneButton.isEnabled = true
            }
        }
    }

    @objc private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
