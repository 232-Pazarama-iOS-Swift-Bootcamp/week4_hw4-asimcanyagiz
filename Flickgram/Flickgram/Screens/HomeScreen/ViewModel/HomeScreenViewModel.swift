//
//  HomeScreenViewModel.swift
//  Flickgram
//
//  Created by Asım can Yağız on 15.10.2022.
//

import Foundation
import Moya
import FirebaseFirestore

@objc
protocol FavoritePhotoDelegate: AnyObject {
    @objc optional func didErrorOccurred(_ error: Error)
    @objc optional func didPhotoAddedToFavorites()
}

//Cases for change photos
enum PhotosChanges {
    case didErrorOccurred(_ error: Error)
    case didFetchPhotos
}

final class HomeScreenViewModel: CAViewModel {
    
    //Basic firebase connections
    weak var delegate: FavoritePhotoDelegate?
    
    private let db = Firestore.firestore()
    
    private let defaults = UserDefaults.standard
    
    private var photosResponse: PhotosResponse? {
        didSet {
            self.changeHandler?(.didFetchPhotos)
        }
    }
    
    var changeHandler: ((PhotosChanges) -> Void)?
    
    
    var numberOfRows: Int {
        photosResponse?.photos?.photo?.count ?? .zero
    }
    
    //MARK: - Functions
    //Fetch the photos from api
    func fetchPhotos() {
        provider.request(.recentPhotos) { result in
            switch result {
            case .failure(let error):
                self.changeHandler?(.didErrorOccurred(error))
            case .success(let response):
                do {
                    let photosResponse = try JSONDecoder().decode(PhotosResponse.self, from: response.data)
                    self.photosResponse = photosResponse
                } catch {
                    self.changeHandler?(.didErrorOccurred(error))
                }
            }
        }
    }
    
    //Search the photos from api
    func searchPhotos(searchText: String) {
        provider.request(.searchPhotos(text: searchText)) { result in
            switch result {
            case .failure(let error):
                self.changeHandler?(.didErrorOccurred(error))
            case .success(let response):
                do {
                    let photosResponse = try JSONDecoder().decode(PhotosResponse.self, from: response.data)
                    self.photosResponse = photosResponse
                } catch {
                    self.changeHandler?(.didErrorOccurred(error))
                }
            }
        }
    }
    
    //Call the current photo
    func photoForIndexPath(_ indexPath: IndexPath) -> Photo? {
        photosResponse?.photos?.photo?[indexPath.row]
    }
    
    //Add the favorite photo url from indexnumber
    func addFavorite(_ number: Int) {
        guard let id = photosResponse?.photos?.photo?[number].iconUrl.absoluteString,
              let uid = defaults.string(forKey: UserDefaultConstants.uid.rawValue) else {
            return
        }
        
        db.collection("users").document(uid).updateData([
            "favorites": FieldValue.arrayUnion([id])
        ])
        
        delegate?.didPhotoAddedToFavorites?()
    }
    
    
    private var number = [String]()
    
    var personalNumberOfRows: Int {
        number.count
    }
    
    func photosForIndexPaths(_ indexPath: IndexPath) -> String? {
        number[indexPath.row]
    }
    
    //Function for fetch favorite photo urls from firebase
    func fetchFavorites(_ completion: @escaping (Error?) -> Void) {
        
        number = []
        
        guard let uid = uid else {
            return
        }
        
        db.collection("users").document(uid).getDocument() { (querySnapshot, err) in
            guard let data = querySnapshot?.data() else {
                return
            }
            let user = User(from: data)
            
            user.favorites?.forEach({
                word in
                if self.number.contains(word) {
                    return
                }
                self.number.append(word)
                
            })
        }
    }
}
