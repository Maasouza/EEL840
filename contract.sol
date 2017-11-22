
pragma solidity ^0.4.2;


contract Mark1 {
    
    string public name;
    string public symbol;
    uint256 public totalSupply;

    mapping ( address => uint256) private balanceOf;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);

    function Mark1 (
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        totalSupply = initialSupply;
        balanceOf[msg.sender] = totalSupply;
        name = tokenName;
        symbol = tokenSymbol;
    }


    function _transfer(address _from, address _to , uint256 _value){

        require ( _to != 0x0 );
        require ( balanceOf[_from] >= _value);
        require ( balanceOf[_to] + value > balanceOf[_to]);

        uint256previousBalances = balanceOf[_from] + balanceOf[_to];

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;

        Transfer( _from , _to , _value );
        
        assert( balanceOf[_from] + balanceOf[_to] == previousBalances );

    }

    function transfer(address _to , uint256 _value){
        _transfer( msg.sender , _to , _value);
    }

}