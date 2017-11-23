
pragma solidity ^0.4.2;


contract Mark1 {
    
    string public name;
    string public symbol;
    uint256 public totalWeight;

    mapping (address => uint256) private votingWeight;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);

    function Mark1 (
        uint256 initialWeight,
        string tokenName,
        string tokenSymbol
    ) public 
    {
        totalWeight = initialWeight;
        votingWeight[msg.sender] = totalWeight;
        name = tokenName;
        symbol = tokenSymbol;
    }


    function _transfer(address _from, address _to, uint256 _value) internal 
    {

        require (_to != 0x0);
        require (votingWeight[_from] >= _value);
        require (votingWeight[_to] + _value > votingWeight[_to]);

        uint256 previousBalances = votingWeight[_from] + votingWeight[_to];

        votingWeight[_from] -= _value;
        votingWeight[_to] += _value;

        Transfer(_from, _to, _value );
        
        assert(votingWeight[_from] + votingWeight[_to] == previousBalances);

    }

    function transfer(address _to, uint256 _value) public 
    {
        _transfer(msg.sender, _to, _value);
    }

}