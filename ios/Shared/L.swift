//
//  L.swift
//  Runner
//
//  Created by Airon on 01.08.2021.
//

import Foundation

public class L {
  
  var tag: String
  
  init(_ tag: String) {
    self.tag = tag
  }
  
  func i(_ message: String) {
    print("-> \(pad(tag)) - \(message)")
  }
  
  //
  private func pad(_ tag: String) -> String {
    let remainSpacesCount = 30 - tag.count
    var innerTag = tag
    for _ in 0...remainSpacesCount {
      innerTag = " " + innerTag
    }
    return innerTag
  }
  
}
