import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let status = UILabel()
    private let indicator = UIActivityIndicatorView(style: .large)
    private var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        status.text = "Recebendo imagens no Foteka…"
        status.textAlignment = .center
        status.numberOfLines = 0
        status.font = .preferredFont(forTextStyle: .headline)
        let column = UIStackView(arrangedSubviews: [indicator, status])
        column.axis = .vertical
        column.spacing = 20
        column.alignment = .center
        column.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(column)
        NSLayoutConstraint.activate([
            column.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            column.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            column.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            column.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
        indicator.startAnimating()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        Task { await receive() }
    }

    private func receive() async {
        do {
            let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
            var count = 0
            for provider in providers {
                let type = provider.registeredTypeIdentifiers.first { id in
                    UTType(id)?.conforms(to: .image) == true
                }
                guard let type else { continue }
                try await copyImage(provider: provider, typeIdentifier: type)
                count += 1
            }
            guard count > 0 else { throw InboxError.unsupportedType }
            indicator.stopAnimating()
            status.text = "\(count) imagem(ns) enviada(s). Abra Foteka para organizar."
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        } catch {
            indicator.stopAnimating()
            status.text = "Falha ao importar: \(error.localizedDescription)"
            let dismiss = UIButton(type: .system)
            dismiss.setTitle("Fechar", for: .normal)
            dismiss.addTarget(self, action: #selector(cancel), for: .touchUpInside)
            dismiss.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(dismiss)
            NSLayoutConstraint.activate([
                dismiss.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                dismiss.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 30)
            ])
        }
    }

    private func copyImage(provider: NSItemProvider, typeIdentifier: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _ = provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { temp, error in
                if let error { continuation.resume(throwing: error); return }
                guard let temp else { continuation.resume(throwing: InboxError.unsupportedType); return }
                do {
                    // NSItemProvider's temporary file only lives during this completion callback.
                    let ext = UTType(typeIdentifier)?.preferredFilenameExtension ?? temp.pathExtension
                    try InboxFileStore.enqueue(fileAt: temp, suggestedExtension: ext)
                    continuation.resume(returning: ())
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: InboxError.unsupportedType)
    }
}
