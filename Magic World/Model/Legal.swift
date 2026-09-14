//
//  Legal.swift
//  Magic World
//
//  Os dois documentos que a App Store exige de qualquer app com assinatura,
//  num lugar so porque aparecem em mais de um.
//
//  ONDE ELES PRECISAM ESTAR
//
//  1. No paywall, visiveis antes da compra. A Apple recusa uma tela de
//     assinatura sem link pros termos e pra politica de privacidade.
//  2. Nos ajustes, pra quem ja assinou e quer reler depois.
//  3. Nos metadados do App Store Connect, nos campos proprios de Privacy
//     Policy URL e License Agreement — que sao SEPARADOS do app e nao sao
//     preenchidos por ter os links aqui dentro.
//
//  Os itens 1 e 2 estao feitos. O 3 e no navegador, e nao da pra fazer
//  daqui.
//

import Foundation

enum Legal {
    /// Politica de privacidade e EULA no mesmo documento.
    static let privacy = URL(
        string: "https://marked-garage-d75.notion.site/"
              + "Magic-world-Privacy-Policy-EULA-"
              + "3d62f13e5f7d80aa9f0fde076524dd7b")!

    /// Termos de uso e suporte no mesmo documento.
    static let terms = URL(
        string: "https://marked-garage-d75.notion.site/"
              + "Magic-world-Terms-of-use-Support-"
              + "3d62f13e5f7d80c396ecf7015e2076da")!
}
