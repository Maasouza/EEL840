pragma solidity ^0.4.2;

import "strings.sol";

contract Mark1 {

    using strings for *;
    
    string public name;
    string public symbol;
    uint256 public totalWeight;
    uint public initID;

    struct Voter {
        uint256 votingWeight; // peso do votante. análogo a balance em $
        mapping (address => uint) delegatesWeight; // para quem você delegou votos e quantos votos foram delegados
        address[] delegates; // array de para quem você delegou votos
        mapping (string => uint) voted;
    }

    struct Proposal {
        string name;
        string description;
        string[] options;
        bool exists;
        uint activeUntil;
        mapping (string => uint) votes;
    }

    mapping (address => Voter) private voters; // associação entre contas e eleitores
    mapping (uint => Proposal) private proposals;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
    event AskBack(address indexed from, address indexed to, uint256 value);
    event CreateProposal(string name, string description, string options, uint ttl);
    event Vote(address indexed voter, uint proposal, string option, uint value);

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function Mark1 (
        uint256 initialWeight, // peso total da rede
        string tokenName, // nome do token/voto
        string tokenSymbol // símbolo do token
    ) public 
    {
        totalWeight = initialWeight;
        voters[msg.sender].votingWeight = totalWeight;
        name = tokenName;
        symbol = tokenSymbol;
        initID = 0;
    }

    /**
     * Function to create a new proposal
     *
     * 
     */
    function createProposal(string name, string description, string options, uint ttl) public {
        require(proposals[initID].exists);
        Proposal newProposal;
        
        var opts = options.toSlice();
        var delim = ",".toSlice();
        var parts = new string[](opts.count(delim));
        for (uint i = 0; i < parts.length; i++) {
            parts[i] = opts.split(delim).toString();
        }

        newProposal.name = name;
        newProposal.description = description;
        newProposal.options = parts;
        newProposal.exists = true;
        newProposal.activeUntil = now + ttl;
        proposals[initID] = newProposal;
        initID++;

        CreateProposal(name, description, options, ttl);
        assert(proposals[initID-1].exists);
    }

    function vote(uint proposal, uint option, uint value) public {
        require(voters[msg.sender].votingWeight >= value);
        require(proposals[proposal].exists);
        require(proposals[proposal].activeUntil <= now);
        require(proposals[proposal].options.length > option);

        string selectedOption =  proposals[proposal].options[option];
        uint previousBalances = voters[msg.sender].votingWeight + proposals[proposal].votes[selectedOption];

        proposals[proposal].votes[selectedOption] += value;
        voters[msg.sender].votingWeight -= value;
        voters[msg.sender].voted[selectedOption] += value;

        Vote(msg.sender, proposal, selectedOption, value);

        assert(previousBalances == voters[msg.sender].votingWeight + proposals[proposal].votes[selectedOption]);
    }

    function undoVote(uint proposal, uint option, uint value) public {
        require(proposals[proposal].exists);
        string selectedOption =  proposals[proposal].options[option];
        require(proposals[proposal].votes[selectedOption] >= value);
        require(voters[msg.sender].voted[selectedOption] >= value);

        uint previousBalances = voters[msg.sender].votingWeight + proposals[proposal].votes[selectedOption];

        proposals[proposal].votes[selectedOption] -= value;
        voters[msg.sender].voted[selectedOption] -= value;
        voters[msg.sender].votingWeight += value;

        assert(previousBalances == voters[msg.sender].votingWeight + proposals[proposal].votes[selectedOption]);
    }
    
    /**
     *  isso pode ou não funcionar
     *  supostamente dá 1 voto a qualquer pessoa que pedir
     *  ideia é implementar autenticação nessa função. 1 eleitor = 1 voto
     */
    function faucet() internal {
        voters[msg.sender].votingWeight += 1;
        totalWeight += 1;
    }

    function min(uint a, uint b) public pure returns (uint) {
        return (a < b) ? a : b;
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */ 
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint256 _value) internal {

        require(_to != 0x0);
        require(voters[_from].votingWeight >= _value);
        require(voters[_to].votingWeight + _value > voters[_to].votingWeight);

        uint256 previousBalances = voters[_from].votingWeight + voters[_to].votingWeight;
        // 
        voters[_from].votingWeight -= _value;
        voters[_to].votingWeight += _value;

        // guarda para quem o usuário delegou seus votos e quantos votos foram delegados 
        if (voters[_from].delegatesWeight[_to] != 0) {
            voters[_from].delegatesWeight[_to] += _value;
        } else {
            voters[_from].delegatesWeight[_to] = _value;
            voters[_from].delegates.push(_to);
        }

        Transfer(_from, _to, _value);

        assert(voters[_from].votingWeight + voters[_to].votingWeight == previousBalances);
        assert(voters[_from].delegatesWeight[_to] != 0);

    }

   /**
     * Transfer Back
     *
     * Efetuará a transação chamada pelo AskBack
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
    */ 
    function _transferBack(address _from, address _to, uint256 _value) internal {

        require(_to != 0x0);
        require(voters[_from].votingWeight >= _value);
        require(voters[_to].votingWeight + _value > voters[_to].votingWeight);

        uint256 previousBalances = voters[_from].votingWeight + voters[_to].votingWeight;

        voters[_from].votingWeight -= _value;
        voters[_to].votingWeight += _value;
        voters[_to].delegatesWeight[_from] -= _value;

        if (voters[_to].delegatesWeight[_from] == 0) {
            delete voters[_to].delegatesWeight[_from];
            
            for (uint i = 0; i < voters[_to].delegates.length; i++) {
                if (voters[_to].delegates[i] == _from) {
                    delete voters[_to].delegates[i];
                    break;
                }
            }

        }

        Transfer(_from, _to, _value);

        assert(voters[_from].votingWeight + voters[_to].votingWeight == previousBalances);
        assert(voters[_to].delegatesWeight[_from] == 0);

    }

   /**
    * Ask Back
    * Pede a um delegado que devolva os votos que foram emprestados a ele ou 
    * devolve os votos enquanto a votação está ativa.
    *
    * @param _from Quem está pedindo os votos de volta
    * @param _to Para quem os votos foram emprestados
    * @param _value Quantos votos estão sendo pedidos 
    */
    function _askBack(address _from, address _to, uint256 _value) internal {
        require(_to != 0x0);
        require(voters[_from].delegatesWeight[_to] != 0);
        require(voters[_from].delegatesWeight[_to] >= _value);

        if (voters[_to].votingWeight < _value) {
           /**
            * Se o delegado não tem os votos necessários para devolver aqueles que lhes foram 
            * emprestados, ele precisa pedir devolta votos aos seus próprios delegados.
            */
            bool need = true;
            for (uint i = 0; i < voters[_to].delegates.length; i++) {
                uint placeholder = voters[_to].votingWeight;
                address newTo = voters[_to].delegates[i];
                uint askValue = min(_value - placeholder, voters[_to].delegatesWeight[newTo]);
                _askBack(_to, newTo, askValue);
                placeholder = voters[_to].votingWeight;
                if (_value == placeholder) { need = false; break; }
            
            }
            //condição de ja ter votado
            //if (voters[_to].votingWeight < _value) {
                //uint needed = _value - voters[_to].votingWeight;
            uint proposal = initID - 1;
            while ((_value - voters[_to].votingWeight != 0) && need) {
                for (uint id = 0; id < proposals[proposal].options.length; id++) {
                    string selectedOption = proposals[proposal].options[id];
                    if (voters[_from].voted[selectedOption] >= 1) {
                        undoVote(proposal, id, 1);
                    }
                }
            }
            //}             
        }

        _transferBack(_to, _from, _value);

    }

    function askBack(address _to, uint256 _value) public {
        _askBack(msg.sender, _to, _value);
    }

}
