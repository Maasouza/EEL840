
pragma solidity ^0.4.2;


contract Mark1 {
    
    string public name;
    string public symbol;
    uint256 public totalWeight;

    struct Voter {
        uint256 votingWeight;
        mapping (address => uint) delegatesWeight;
        address[] delegates;
    }

    mapping (address => Voter) private voters;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
    event AskBack(address indexed from, address indexed to, uint256 value);


    function Mark1 (
        uint256 initialWeight,
        string tokenName,
        string tokenSymbol
    ) public 
    {
        totalWeight = initialWeight;
        voters[msg.sender].votingWeight = totalWeight;
        name = tokenName;
        symbol = tokenSymbol;
    }
    
    function _transfer(address _from, address _to, uint256 _value) internal 
    {

        require (_to != 0x0);
        require (voters[_from].votingWeight >= _value);
        require (voters[_to].votingWeight + _value > voters[_to].votingWeight);

        uint256 previousBalances = voters[_from].votingWeight + voters[_to].votingWeight;

        voters[_from].votingWeight -= _value;
        voters[_to].votingWeight += _value;
        
        if (voters[_from].delegatesWeight[_to].isValue)
        {
            voters[_from].delegatesWeight[_to] += _value;
        }
        else
        {
            voters[_from].delegatesWeight[_to] = _value;
            voters[_from].delegates.push(_to);
        }

        Transfer(_from, _to, _value );

        assert(voters[_from].votingWeight + voters[_to].votingWeight == previousBalances);
        assert(voters[_from].delegatesWeight[_to].isValue);

    }

    function _transferBack(address _from, address _to, uint256 _value) internal 
    {

        require (_to != 0x0);
        require (voters[_from].votingWeight >= _value);
        require (voters[_to].votingWeight + _value > voters[_to].votingWeight);

        uint256 previousBalances = voters[_from].votingWeight + voters[_to].votingWeight;

        voters[_from].votingWeight -= _value;
        voters[_to].votingWeight += _value;
        voters[_to].delegatesWeight[_from] -= _value;

        if(voters[_to].delegatesWeight[_from] == 0)
        {
            delete voters[_to].delegatesWeight[_from];
            
            for(uint i = 0 ; i < voters[_to].delegates.length ; i++)
            {
                if( voters[_to].delegates[i] == _from )
                {
                    delete voters[_to].delegates[i];
                    break;
                }
            }

        }

        Transfer(_from, _to, _value );

        assert(voters[_from].votingWeight + voters[_to].votingWeight == previousBalances);
        assert(!voters[_to].delegatesWeight[_from].isValue);

    }

    

    function _askBack(address _from, address _to, uint256 _value) internal
    {
        require(_to != 0x0);
        require(voters[_from].delegatesWeight[_to].isValue);
        require(voters[_from].delegatesWeight[_to] >= _value);

        if (voters[_to].votingWeight < _value )
        {
            for (uint i = 0 ; i < voters[_to].delegates.length ; i++)
            {
                uint placeholder = voters[_to].votingWeight;
                address new_to = voters[_to].delegates[i];
                uint ask_value = min(_value - placeholder, voters[_to].delegatesWeight[new_to]);
                _askBack(_to, new_to, ask_value);
                placeholder = voters[_to].votingWeight;
                if(_value == placeholder)
                {
                    break;
                }
            }

            //condição de ja ter votado
        }   

    }

    function transfer(address _to, uint256 _value) public 
    {
        _transfer(msg.sender, _to, _value);
    }

}
