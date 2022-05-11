import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import NFTActorClass "../NFT/nft";
// import Cycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import List "mo:base/List";
import Iter "mo:base/Iter";

actor OpenD {

    private type Listing = {
        itemOwner: Principal;
        itemPrice: Nat;
    };

    var mapOfNFTs = HashMap.HashMap<Principal, NFTActorClass.NFT>(1, Principal.equal, Principal.hash);
    var mapOfOwners = HashMap.HashMap<Principal,List.List<Principal>>(1, Principal.equal, Principal.hash);
    var mapOfListings = HashMap.HashMap<Principal, Listing>(1, Principal.equal, Principal.hash);

    public shared(msg) func mint(imgData: [Nat8], name: Text) : async Principal
    {
        let owner :  Principal = msg.caller;

        //// We need to add cycle if we are deploying this live inorder to run this canister
        //// Adding 100 billion cycles to create new canister and 500 million cycles to keep canister up and running
        // Debug.print(debug_show(Cycles.balance()));
        // Cycles.add(100_500_000_000);

        let newNFT = await NFTActorClass.NFT(name, owner, imgData);
        let newNFTPrincipal = await newNFT.getCanisterId();

        mapOfNFTs.put(newNFTPrincipal, newNFT);
        addToOwnershipMap(owner, newNFTPrincipal);
        return newNFTPrincipal;
    };

    private func addToOwnershipMap(owner: Principal, nftId: Principal){
        var ownedNFTs : List.List<Principal> = switch(mapOfOwners.get(owner)) {
            case null List.nil<Principal>();
            case (?result) result;
        };

        ownedNFTs := List.push(nftId, ownedNFTs);
        mapOfOwners.put(owner, ownedNFTs);
    };

    public query func getOwnedNFTs(user : Principal) : async [Principal] {
        var userNFTs : List.List<Principal> = switch(mapOfOwners.get(user)) {
            case null List.nil<Principal>();
            case (?result) result;
        };

        return List.toArray(userNFTs);
    };

    public query func getListedNFTs() : async [Principal]{
        let ids = Iter.toArray(mapOfListings.keys());
        return ids;
    };

    public shared(msg) func listItem(id: Principal, price: Nat) : async Text {
        // get NFT 
        var item : NFTActorClass.NFT = switch(mapOfNFTs.get(id)){
            case null return "NFT does not exist.";
            case (?result) result;
        };

        // check if user is the correct owner of NFT
        let owner = await item.getOwner();
        if(Principal.equal(owner, msg.caller)){
            // create listing for given NFT
            let newListing : Listing = {
                itemOwner = owner;
                itemPrice = price;
            };
            mapOfListings.put(id, newListing);
            return "Success";
        } else {
            return "You don't own the NFT";
        }
    };

    public query func getOpenDCanisterId() : async Principal {
        return Principal.fromActor(OpenD);
    };

    public query func isListed(id: Principal) : async Bool {
        if(mapOfListings.get(id) == null){
            return false;
        } else {
            return true;
        }
    };

    public query func getOriginalOwner(ndfId : Principal) : async Principal {
        // Returns orginal owner for given NFT
        let listing : Listing = switch(mapOfListings.get(ndfId)){
            case null return Principal.fromText("");
            case (?result) result;
        };

        return listing.itemOwner;
    };

    public query func getListedNFTPrice(nftId: Principal) : async Nat {
        let listing : Listing = switch(mapOfListings.get(nftId)){
            case null return 0;
            case (?result) result;
        };

        return listing.itemPrice;
    };

    public shared(msg) func completePurchase(id: Principal, ownerId: Principal, newOwnerId: Principal) : async Text {
        var purchasedNFt : NFTActorClass.NFT = switch (mapOfNFTs.get(id)) {
            case null return "NFT does not exist.";
            case (?result) result;
        };

        let transferResult = await purchasedNFt.transferOwnership(newOwnerId);
        if(transferResult == "Success"){
            // delete nft item from listing for that particular owner
            mapOfListings.delete(id);
            var ownedNFTs : List.List<Principal> = switch (mapOfOwners.get(ownerId)) {
                case null List.nil<Principal>();
                case (?result) result;
            };

            ownedNFTs := List.filter(ownedNFTs, func(listItemId : Principal) : Bool {
                return listItemId != id;
            });

            // add this to ownership map of new owner
            addToOwnershipMap(newOwnerId, id);
            return "Success";
        } else {
            return transferResult;
        }        
    };
};
