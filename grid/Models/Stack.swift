//
//  Stack.swift
//  grid
//
//  Created by Yehor Chernenko on 03.12.2021.
//

import Foundation

class Stack<T> {

  private var elements: [T] = []

  func push(_ element: T) {
    elements.append(element)
  }

  func pop() -> T? {
    guard !elements.isEmpty else {
      return nil
    }
    return elements.popLast()
  }

  var top: T? {
    return elements.last
  }
}
