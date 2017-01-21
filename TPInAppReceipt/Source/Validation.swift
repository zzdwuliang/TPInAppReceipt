//
//  InAppReceiptValidator.swift
//  TPInAppReceipt
//
//  Created by Pavel Tikhonenko on 19/01/17.
//  Copyright © 2017 Pavel Tikhonenko. All rights reserved.
//

import Foundation
import openssl



public extension InAppReceipt
{
    public func verify() throws
    {
        try verifySignature()
        try verifyHash()
    }
    
    public func verifySignature() throws
    {
        try pkcs7Container.verifySignature()
    }
    
    public func verifyHash() throws
    {
        if (computedHashData != receiptHash)
        {
            throw IARError.validationFailed(reason: .hashValidationFailed)
        }
    }
}

extension PKCS7Wrapper
{
    func verifySignature() throws
    {
        try checkSignatureExistance(pkcs7: raw)
        let appleCertificate = try appleCertificateData()
        try verifySignature(pkcs7: raw, withCertificateData: appleCertificate)
    }
    
    fileprivate func verifySignature(pkcs7: UnsafeMutablePointer<PKCS7>, withCertificateData data: Data) throws
    {
        let verified: Int32 = 1
        
        let appleRootBIO = BIO_new(BIO_s_mem())
        
        var appleRootBytes = [UInt8](repeating:0, count:data.count)
        data.copyBytes(to: &appleRootBytes, count: data.count)
        BIO_write(appleRootBIO, appleRootBytes, Int32(data.count))
        
        let appleRootX509 = d2i_X509_bio(appleRootBIO, nil)
        let store = X509_STORE_new()
        
        X509_STORE_add_cert(store, appleRootX509)
        OpenSSL_add_all_digests()
        
        let result = PKCS7_verify(pkcs7, nil, store, nil, nil, 0)
        
        BIO_free(appleRootBIO)
        X509_STORE_free(store)
        EVP_cleanup()
        
        if verified != result
        {
            throw IARError.validationFailed(reason: .signatureValidationFailed(.invalidSignature))
        }
    }
    
    fileprivate func checkSignatureExistance(pkcs7: UnsafeMutablePointer<PKCS7>) throws
    {
        if OBJ_obj2nid(pkcs7.pointee.type) != NID_pkcs7_signed
        {
            throw IARError.validationFailed(reason: .signatureValidationFailed(.receiptIsNotSigned))
        }
        
        if OBJ_obj2nid(pkcs7.pointee.d.sign.pointee.contents.pointee.type) != NID_pkcs7_data
        {
            throw IARError.validationFailed(reason: .signatureValidationFailed(.receiptSignedDataNotFound))
        }
    }
    
    fileprivate func appleCertificateData() throws -> Data
    {
        guard let appleRootURL = Bundle.init(for: type(of: self)).url(forResource: "AppleIncRootCertificate", withExtension: "cer") else
        {
            throw IARError.validationFailed(reason: .signatureValidationFailed(.appleIncRootCertificateNotFound))
        }
        
        let appleRootData = try Data(contentsOf: appleRootURL)
        
        if appleRootData.count == 0
        {
            throw IARError.validationFailed(reason: .signatureValidationFailed(.unableToLoadAppleIncRootCertificate))
        }
        
        return appleRootData
    }
}