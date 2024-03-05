// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICurvePool {
    function coins(uint256 index) external view returns (address);
    function asset_types(uint256 index) external view returns (uint8);
    function fee() external view returns (uint256);
    function offpeg_fee_multiplier() external view returns (uint256);
    function admin_fee() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);

    function get_dx(int128 i, int128 j, uint256 dy) external view returns (uint256);
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    function get_virtual_price() external view returns (uint256);
    function calc_token_amount(uint256[] calldata amounts, bool is_deposit) external view returns (uint256);
    function A() external view returns (uint256);
    function A_precise() external view returns (uint256);
    function balances(uint256 i) external view returns (uint256);
    function get_balances() external view returns (uint256[] memory);
    function stored_rates() external view returns (uint256[] memory);
    function dynamic_fee(int128 i, int128 j) external view returns (uint256);

    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy, address receiver) external returns (uint256);
    function exchange_received(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
    function exchange_received(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy,
        address receiver
    )
        external
        returns (uint256);
    function add_liquidity(uint256[] calldata amounts, uint256 min_mint_amount) external returns (uint256);
    function add_liquidity(
        uint256[] calldata amounts,
        uint256 min_mint_amount,
        address receiver
    )
        external
        returns (uint256);
    function remove_liquidity_one_coin(
        uint256 burn_amount,
        int128 i,
        uint256 min_received
    )
        external
        returns (uint256);
    function remove_liquidity_one_coin(
        uint256 burn_amount,
        int128 i,
        uint256 min_received,
        address receiver
    )
        external
        returns (uint256);
    function remove_liquidity_imbalance(
        uint256[] calldata amounts,
        uint256 max_burn_amount
    )
        external
        returns (uint256);
    function remove_liquidity_imbalance(
        uint256[] calldata amounts,
        uint256 max_burn_amount,
        address receiver
    )
        external
        returns (uint256);
    function remove_liquidity(
        uint256 burn_amount,
        uint256[] calldata min_amounts
    )
        external
        returns (uint256[] memory);
    function remove_liquidity(
        uint256 burn_amount,
        uint256[] calldata min_amounts,
        address receiver
    )
        external
        returns (uint256[] memory);
    function remove_liquidity(
        uint256 burn_amount,
        uint256[] calldata min_amounts,
        address receiver,
        bool claim_admin_fees
    )
        external
        returns (uint256[] memory);
    function withdraw_admin_fees() external;

    function ramp_A(uint256 future_A, uint256 future_time) external;
    function stop_ramp_A() external;

    function set_new_fee(uint256 new_fee, uint256 new_offpeg_fee_multiplier) external;
    function set_ma_exp_time(uint256 ma_exp_time, uint256 D_ma_time) external;

    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        returns (bool);

    event TokenExchange(
        address indexed buyer, int128 sold_id, uint256 tokens_sold, int128 bought_id, uint256 tokens_bought
    );
    event AddLiquidity(
        address indexed provider, uint256[] token_amounts, uint256[] fees, uint256 invariant, uint256 token_supply
    );
    event RemoveLiquidity(address indexed provider, uint256[] token_amounts, uint256[] fees, uint256 token_supply);
    event RemoveLiquidityOne(address indexed provider, uint256 token_amount, uint256 coin_amount);
    event RemoveLiquidityImbalance(
        address indexed provider, uint256[] token_amounts, uint256[] fees, uint256 invariant, uint256 token_supply
    );
    event RampA(uint256 old_A, uint256 new_A, uint256 initial_time, uint256 future_time);
    event StopRampA(uint256 A, uint256 t);
}
