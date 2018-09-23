//
//  Config.swift
//  Saitama
//
//  Created by akifumi.fukaya on 2018/09/23.
//  Copyright © 2018年 Yenom. All rights reserved.
//

import BitcoinKit

struct Config {
    static let isMainNet: Bool = false
    static var network: Network {
        return isMainNet ? .mainnet : .testnet
    }
}
