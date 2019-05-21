//
//  ViewController.swift
//  Crawler-Swift
//
//  Created by season on 2019/5/21.
//  Copyright © 2019 season. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    // 基本的URL
    let baseURL = "http://www.acgsou.com"
    
    // 搜索的Api
    let searchApi = "/search.php?keyword="
    
    // 匹配show的正在表达 Swift5 新特性 在##之间的字符串 可以不用\对特殊符号进行转义了
    let showPattern = #"<a href="show-.*" target="_blank">"#
    
    // 用于匹配种子下载地址的正则表达式
    let seedPattern = #"<a id="download" href=".*">"#
    
    // 下载引用的正则匹配
    let hrefPattern = #"href=".*""#
    
    // 下载文件的标题正则匹配
    let titlePattern = #"<title>.*</title>"#
    
    private lazy var animationNameField: UITextField = {
        let textField = UITextField(frame: CGRect(x: 0, y: 0, width: view.frame.width - 20, height: 66))
        textField.placeholder = "输入动画名, 建议 字幕组名称+空格+动画名称"
        textField.center = CGPoint(x: view.center.x, y: view.center.y - 88)
        textField.layer.borderWidth = 1 / UIScreen.main.scale
        textField.layer.borderColor = UIColor.black.cgColor
        textField.layer.cornerRadius = 4
        textField.layer.masksToBounds = true
        return textField
    }()
    
    private lazy var numberField: UITextField = {
        let textField = UITextField(frame: CGRect(x: 0, y: 0, width: view.frame.width - 20, height: 66))
        textField.placeholder = "输入需要搜索的数量,数量过多爬得很慢"
        textField.keyboardType = .numberPad
        textField.center = view.center
        textField.layer.borderWidth = 1 / UIScreen.main.scale
        textField.layer.borderColor = UIColor.black.cgColor
        textField.layer.cornerRadius = 4
        textField.layer.masksToBounds = true
        return textField
    }()
    
    private lazy var searchButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: view.frame.width - 20, height: 66))
        button.setTitle("开始搜索", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.center = CGPoint(x: view.center.x, y: view.center.y + 88)
        button.layer.borderWidth = 1 / UIScreen.main.scale
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.cornerRadius = 4
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(searchButtonAction(_:)), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(animationNameField)
        view.addSubview(numberField)
        view.addSubview(searchButton)
    }
    
    @objc
    private func searchButtonAction(_ button: UIButton) {
        
        view.endEditing(true)
        
        Hud.showWait(message: "正在爬虫", autoClear: false)
        
        guard let keyword = animationNameField.text else {
            Hud.clear()
            return
        }
        
        if keyword.isEmpty {
            Hud.clear()
            return
        }
        
        guard let number = numberField.text else {
            Hud.clear()
            return
        }
        
        guard let num = Int(number) else {
            Hud.clear()
            return
        }
        
        let html = searchByKeyword("进击的巨人")
        
        let showRegex = regex(pattern: showPattern)
        
        let showResults = matchInfo(regex: showRegex, html: html)
        
        let detailURLStrings = self.detailURLStrings(results: showResults, html: html)
        
        guard let details = detailURLStrings else {
            Hud.clear()
            return
        }
        
        let slice: [String]
        if details.count > num {
            slice = Array(details[0 ..< num])
        }else {
            slice = details
        }

        DispatchQueue.global().async {
            let seedDownloadInfos = self.seedDownloadInfos(detailURLStrings: slice)
            //print(seedDownloadInfos)
            
            DispatchQueue.main.async {
                Hud.clear()
                
                Hud.showMessage(message: "爬虫完成", autoClear: true, autoClearTime: 2, responseTap: false) {
                    let animationListController = AniamtionListController(style: .plain)
                    animationListController.seedDownloadInfos = seedDownloadInfos
                    self.navigationController?.pushViewController(animationListController, animated: true)
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}

// MARK: - 爬虫业务
extension ViewController {
    /// 通过输入关键字获取搜索页面的网页字符串
    ///
    /// - Returns: 网页字符串
    func searchByKeyword(_ keyword: String) -> String? {
        
        guard let urlKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        let urlString = baseURL + searchApi + urlKeyword
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        guard let webString = String(data: data, encoding: .utf8) else {
            return nil
        }
        print(webString)
        return webString
    }
    
    /// 通过正则表达式获取一个NSRegularExpression
    ///
    /// - Parameter pattern: 正则表达式
    /// - Returns: NSRegularExpression
    func regex(pattern: String) -> NSRegularExpression? {
        return try? NSRegularExpression(pattern: pattern, options: [])
    }
    
    /// 获取匹配结果
    ///
    /// - Parameters:
    ///   - regex: NSRegularExpression
    ///   - html: 网页
    /// - Returns: 结果集合
    func matchInfo(regex: NSRegularExpression?, html: String?) -> [NSTextCheckingResult]? {
        guard let regex = regex, let html = html else {
            return nil
        }
        
        return regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.count))
    }
    
    /// 获取show-xxx的详细网页
    ///
    /// - Parameters:
    ///   - results: [NSTextCheckingResult]
    ///   - html: 网页
    /// - Returns: 详细网页的集合
    func detailURLStrings(results: [NSTextCheckingResult]?, html: String?) -> [String]? {
        guard let results = results, let html = html else {
            return nil
        }
        
        let nsString = html as NSString
        
        let detailURLStrings = results.map { (result) -> String in
            let show = nsString.substring(with: result.range).replacingOccurrences(of: "<a href=\"", with: "").replacingOccurrences(of: "\" target=\"_blank\">", with: "")
            let detailURL = baseURL + "/" + show
            return detailURL
        }
        
        return detailURLStrings
    }
    
    /// 获取详细页面的标题
    ///
    /// - Parameters:
    ///   - results: [NSTextCheckingResult]
    ///   - html: 网页字符串
    /// - Returns: 标题
    func detailURLTitle(results: [NSTextCheckingResult]?, html: String?) -> String? {
        guard let results = results, let html = html else {
            return nil
        }
        
        let nsString = html as NSString
        
        let titles = results.map { (result) -> String in
            let title = nsString.substring(with: result.range)
                .replacingOccurrences(of: #"<title>"#, with: "")
                .replacingOccurrences(of: #"</title>"#, with: "")
                .replacingOccurrences(of: #" - ACG资源|动漫种子|动漫BT下载 - ACG搜"#, with: "")
            return title
        }
        
        return titles.first
    }
    
    /// 获取详细页面的种子
    ///
    /// - Parameters:
    ///   - results: [NSTextCheckingResult]
    ///   - html: 网页页面
    /// - Returns: 种子引用
    func detailURLSeed(results: [NSTextCheckingResult]?, html: String?) -> String? {
        guard let results = results, let html = html else {
            return nil
        }
        
        let nsString = html as NSString
        
        let seeds = results.map { (result) -> String in
            let seed = nsString.substring(with: result.range)
            return seed
        }
        
        return seeds.first
    }
    
    /// 获取种子信息
    ///
    /// - Parameters:
    ///   - results: [NSTextCheckingResult]
    ///   - seed: 种子引用页面
    ///   - title: 种子标题
    /// - Returns: SeedDownloadInfo
    func getSeedDownloadInfo(results: [NSTextCheckingResult]?, seed: String?, title: String?) -> SeedDownloadInfo? {
        guard let results = results, let seed = seed else {
            return nil
        }
        
        let nsString = seed as NSString
        
        let infos = results.map { (result) -> String in
            let info = nsString.substring(with: result.range)
            return info
        }
        
        guard let firstInfo = infos.first else {
            return nil
        }
        
        let href = firstInfo.replacingOccurrences(of: #"href=""#, with: "").replacingOccurrences(of: "\"", with: "")
        let downloadURL = baseURL + "/" + href
        
        let dateAndHash = (href.replacingOccurrences(of: "down.php?", with: "").split(separator: "&"))
        
        let dateHashs = dateAndHash.map { (subString) -> [String?] in
            let string = String(subString)
            let propertys = string.split(separator: "=")
            let propert = propertys.map { (subString) -> String? in
                let string = String(subString)
                return string
            }
            return propert
        }
        
        guard let date = dateHashs.first?.last, let hash = dateHashs.last?.last else {
            return nil
        }
        
        let seedDownloadInfo = SeedDownloadInfo(url: downloadURL, title: title, date: date, hash: hash)
        return seedDownloadInfo
    }
    
    /// 获取种子的信息
    ///
    /// - Parameter detailURLStrings: 详细网页数组
    /// - Returns: 种子信息数组
    func seedDownloadInfos(detailURLStrings: [String]?) -> [SeedDownloadInfo?]? {
        guard let detailURLStrings = detailURLStrings else {
            return nil
        }
        
        let seedRegex = regex(pattern: seedPattern)
        
        let titleRegex = regex(pattern: titlePattern)
        
        let hrefRegex = regex(pattern: hrefPattern)
        
        let seedDownloadInfos = detailURLStrings.map { (detailURLString) -> SeedDownloadInfo? in
            guard let url = URL(string: detailURLString) else {
                return nil
            }
            
            guard let data = try? Data(contentsOf: url) else {
                return nil
            }
            
            guard let detailWebString = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let titleResults = matchInfo(regex: titleRegex, html: detailWebString)
            let title = detailURLTitle(results: titleResults, html: detailWebString)
            
            let seedResults = matchInfo(regex: seedRegex, html: detailWebString)
            let seed = detailURLSeed(results: seedResults, html: detailWebString)
            
            let hrefResults = matchInfo(regex: hrefRegex, html: seed)
            let seedDownloadInfo = getSeedDownloadInfo(results: hrefResults, seed: seed, title: title)
            return seedDownloadInfo
        }
        
        return seedDownloadInfos
    }
}

/// 种子信息
struct SeedDownloadInfo {
    var url: String?
    var title: String?
    var date: String?
    var hash: String?
}

