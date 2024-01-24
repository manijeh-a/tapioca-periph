// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {RebaseLibrary} from "@boringcrypto/boring-solidity/contracts/libraries/BoringRebase.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// Tapioca
import {ITapiocaOptionLiquidityProvision} from
    "tapioca-periph/interfaces/tap-token/ITapiocaOptionLiquidityProvision.sol";
import {ITapiocaOptionBroker} from "tapioca-periph/interfaces/tap-token/ITapiocaOptionBroker.sol";
import {IYieldBoxTokenType} from "tapioca-periph/interfaces/yieldBox/IYieldBox.sol";
import {ITapiocaOracle} from "tapioca-periph/interfaces/periph/ITapiocaOracle.sol";
import {ITapiocaOFT} from "tapioca-periph/interfaces/tap-token/ITapiocaOFT.sol";
import {ICommonData} from "tapioca-periph/interfaces/common/ICommonData.sol";
import {ISingularity} from "tapioca-periph/interfaces/bar/ISingularity.sol";
import {ICluster} from "tapioca-periph/interfaces/periph/ICluster.sol";
import {IUSDOBase} from "tapioca-periph/interfaces/bar/IUSDO.sol";

contract MagnetarV2Storage is IERC721Receiver {
    // --- ACTIONS DATA ----
    struct Call {
        MagnetarAction id;
        address target;
        uint256 value;
        bool allowFailure;
        bytes call;
    }

    // --- ACTIONS IDS ----
    enum MagnetarAction {
        Permit, // Permit singular operations.
        Toft, //  TOFT Singular operations.
        Market, // Market Singular related operations.
        TapToken, // TapToken Singular related operations.
        MarketModule, // Market Module related operations.
        YieldboxModule // YieldBox module related operations.

    }
    // --- MODULES IDS ----
    enum Module {
        Market,
        Yieldbox
    }

    // ************ //
    // *** VARS *** //
    // ************ //

    ICluster public cluster;
    mapping(Module moduleId => address moduleAddress) public modules;

    // ************** //
    // *** EVENTS *** //
    // ************** //
    
    event ClusterSet(ICluster indexed oldCluster, ICluster indexed newCluster);

    // ************** //
    // *** ERRORS *** //
    // ************** //

    error NotAuthorized(address caller); // msg.send is neither the owner nor whitelisted by Cluster
    error TargetNotWhitelisted(address target); // Target contract is not whitelisted for an external call
    error UnknownReason(); // Revert reason not recognized
    error ModuleNotFound(Module module); // Module not found

    // ********************** //
    // *** PUBLIC METHODS *** //
    // ********************** //

    /// @notice IERC721Receiver implementation
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // ************************ //
    // *** INTERNAL METHODS *** //
    // ************************ //

    function _executeModule(Module _module, bytes memory _data) internal returns (bytes memory returnData) {
        bool success = true;
        address module = modules[_module];
        if (module == address(0)) revert ModuleNotFound(_module);

        (success, returnData) = module.delegatecall(_data);
        if (!success) {
            _getRevertMsg(returnData);
        }
    }

    function _checkSender(address _from) internal view {
        if (_from != msg.sender && !cluster.isWhitelisted(0, msg.sender)) {
            revert NotAuthorized(msg.sender);
        }
    }

    function _getRevertMsg(bytes memory _returnData) internal pure {
        // If the _res length is less than 68, then
        // the transaction failed with custom error or silently (without a revert message)
        if (_returnData.length < 68) revert UnknownReason();

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        revert(abi.decode(_returnData, (string))); // All that remains is the revert string
    }

    receive() external payable virtual {}
}
