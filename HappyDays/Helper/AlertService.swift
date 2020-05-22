//
//  AlertService.swift
//  HappyDays
//
//  Created by Lasse Silkoset on 22/05/2020.
//  Copyright © 2020 Lasse Silkoset. All rights reserved.
//

import UIKit

class AlertService {
    
    private init() {}
    
    static func addAlert(title: String, message: String, in vc: UIViewController, handler: ((UIAlertAction) -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let action = UIAlertAction(title: "Ok", style: .default, handler: handler)
        
        alert.addAction(action)
        vc.present(alert, animated: true)
    }
}
