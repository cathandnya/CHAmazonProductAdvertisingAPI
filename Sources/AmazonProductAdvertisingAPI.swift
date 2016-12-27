//
//  AmazonProductAdvertisingAPI.swift
//  PerfectTemplate
//
//  Created by nya on 12/21/16.
//
//

import Foundation
import PerfectXML
import COpenSSL

fileprivate func escape(_ key: String) -> String {
    var set = CharacterSet.alphanumerics
    set.insert(charactersIn: "-_.~")
    return key.addingPercentEncoding(withAllowedCharacters: set)!
}

fileprivate func hmacSha256(string: String, key: String) -> String? {
    guard let cKey = key.cString(using: .utf8), let cData = string.cString(using: .utf8) else {
        return nil
    }
    var result = [CUnsignedChar](repeating: 0, count: Int(SHA256_DIGEST_LENGTH + 1))
    var resultLen = UInt32(SHA256_DIGEST_LENGTH)
    HMAC(EVP_sha256(), cKey, Int32(strlen(cKey)), cData.map({ UInt8($0) }), Int(strlen(cData)), &result, &resultLen)
    let hmacData = Data(bytes: result, count: (Int(resultLen)))
    let hmacBase64 = hmacData.base64EncodedString(options: .lineLength76Characters)
    return String(hmacBase64)
}

class AmazonProductAdvertisingAPI {
    
    static let BASE_URL = "http://webservices.amazon.co.jp/onca/xml"

    class func request(url: URL, method: String, queries: [String: String], accessKeyId: String, secretAccessKeyId: String) -> URLRequest? {
        guard let host = url.host, let timestamp: String = {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                fmt.timeZone = TimeZone(secondsFromGMT: 0)
                fmt.locale = Locale(identifier: "en_US")
                return fmt.string(from: Date())
            }() else {
            return nil
        }
        
        var queries = queries
        queries["AWSAccessKeyId"] = accessKeyId
        queries["Timestamp"] = timestamp
        
        var queryString = ""
        var flag = false
        queries.keys.sorted().forEach({ key in
            let val = escape(queries[key]!)
            if flag {
                queryString += "&"
            }
            queryString += key + "=" + val
            flag = true
        })
        
        let toSign =
            method + "\n" +
            host + "\n" +
            url.path + "\n" +
            queryString
        
        guard let auth = hmacSha256(string: toSign, key: secretAccessKeyId) else {
            return nil
        }

        let urlString = "http://" + host + url.path + "?" + queryString + "&Signature=" + escape(auth)
        return URL(string: urlString).flatMap { URLRequest(url: $0) }
    }
    
    class func send(queries: [String: String], accessKeyId: String, secretAccessKeyId: String, completion: @escaping (XDocument?, Error?) -> Void) {
        guard let req = request(url: URL(string: BASE_URL)!, method: "GET", queries: queries, accessKeyId: accessKeyId, secretAccessKeyId: secretAccessKeyId) else {
            completion(nil, NSError(domain: "AWS", code: -1, userInfo: nil))
            return
        }
        
        URLSession.shared.dataTask(with: req) { (data, res, err) in
            if let data = data, let str = String(data: data, encoding: .utf8) {
                completion(XDocument(fromSource: str), nil)
            } else {
                completion(nil, err)
            }
        }.resume()
    }
    
    // MARK:-
    
    var accessKeyId: String
    var secretAccessKeyId: String
    var associateTag: String
    
    init(accessKeyId: String, secretAccessKeyId: String, associateTag: String) {
        self.accessKeyId = accessKeyId
        self.secretAccessKeyId = secretAccessKeyId
        self.associateTag = associateTag
    }
    
    func send(queries: [String: String], completion: @escaping (XDocument?, Error?) -> Void) {
        AmazonProductAdvertisingAPI.send(queries: queries, accessKeyId: accessKeyId, secretAccessKeyId: secretAccessKeyId, completion: completion)
    }

    // MARK:-

    func lookUp(isbn: String, otherParams: [String: String], completion: @escaping ([XNode]?, Error?) -> Void) {
        var params = otherParams
        params["Service"] = "AWSECommerceService";
        params["Operation"] = "ItemLookup";
        params["AssociateTag"] = associateTag;
        params["IdType"] = "ASIN";
        params["ItemId"] = isbn;
        send(queries: params) { (xml, err) in
            if let xml = xml {
                switch xml.extract(path: "/items/item") {
                case .nodeSet(let items):
                    completion(items, nil)
                default:
                    completion(nil, nil)
                }
            } else {
                completion(nil, err)
            }
        }
    }
}
