//
//  Messages.swift
//  NothingOS
//
//  Created by Wafi Choudhury on 12/20/24.
//
import Foundation

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
}
