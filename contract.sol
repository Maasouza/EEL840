pragma solidity ^0.4.2;


contract Mark1 {

    string public name;
    string public symbol;
    uint256 public totalWeight;
    uint public initID;

    struct Voter {
        mapping (address => uint) delegatesWeight; // para quem você delegou votos e quantos votos foram delegados
        address[] delegates; // array de para quem você delegou votos
        mapping (string => uint) voted;
    }

    struct Proposal {
        string name;
        string description;
        string[2] options;
        bool exists;
        uint activeUntil;
        mapping (string => uint) votes;
    }

    mapping (address => Voter) private voters; // associação entre contas e eleitores
    mapping (address => uint256) private balanceOf; 
    mapping (uint => Proposal) private proposals;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
    event AskBack(address indexed from, address indexed to, uint256 value);
    event CreateProposal(string name, string description, string options, uint ttl, uint initID);
    event Vote(address indexed voter, uint proposal, string option, uint value);
    event Winner(string option);

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
        balanceOf[msg.sender] = totalWeight;
        name = tokenName;
        symbol = tokenSymbol;
        initID = 0;
    }

    /**
     * Function to create a new proposal
     *
     * @param _name Nome da proposta
     * @param _description Descrição da proposta
     * @param _min Tempo (em minutos) que a proposta ficará ativa
     */
    function createProposal(string _name, string _description, uint _min) public {
        require(!proposals[initID].exists);
        Proposal memory newProposal;

        newProposal.name = _name;
        newProposal.description = _description;
        newProposal.options = ["nao", "sim"];
        newProposal.exists = true;
        newProposal.activeUntil = now + 60*_min;
        proposals[initID] = newProposal;
        CreateProposal(_name, _description, "nao,sim", _min, initID);
        initID++;

        assert(proposals[initID-1].exists);
    }

    function proposalResult(uint propID) public {
        require(proposals[propID].exists);
        //require(proposals[propID].activeUntil < now);

        Winner(proposals[propID].name);
        if (proposals[propID].votes["sim"] > proposals[propID].votes["nao"]) {
            Winner("sim");
        } else {
            Winner("nao");
        }
    }

    function vote(uint proposal, bool option, uint value) public {
        require(balanceOf[msg.sender] >= value);
        require(proposals[proposal].exists);
        require(proposals[proposal].activeUntil >= now);

        string storage selectedOption =  proposals[proposal].options[conversor(option)];
        uint previousBalances = balanceOf[msg.sender] + proposals[proposal].votes[selectedOption];

        proposals[proposal].votes[selectedOption] += value;
        balanceOf[msg.sender] -= value;
        voters[msg.sender].voted[selectedOption] += value;

        Vote(msg.sender, proposal, selectedOption, value);

        assert(previousBalances == balanceOf[msg.sender] + proposals[proposal].votes[selectedOption]);
    }

    function undoVote(uint proposal, bool option, uint value) public {
        require(proposals[proposal].exists);
        string storage selectedOption =  proposals[proposal].options[conversor(option)];
        require(proposals[proposal].votes[selectedOption] >= value);
        require(voters[msg.sender].voted[selectedOption] >= value);

        uint previousBalances = balanceOf[msg.sender] + proposals[proposal].votes[selectedOption];

        proposals[proposal].votes[selectedOption] -= value;
        voters[msg.sender].voted[selectedOption] -= value;
        balanceOf[msg.sender] += value;

        assert(previousBalances == balanceOf[msg.sender] + proposals[proposal].votes[selectedOption]);
    }
    
    function authenticate() public {
        faucet(msg.sender);
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

    function askBack(address _to, uint256 _value) public {
        _askBack(msg.sender, _to, _value);
    }

    /**
     *  dá 1 voto a qualquer pessoa que pedir
     *  ideia é implementar autenticação nessa função. 1 eleitor = 1 voto
     */
    function faucet(address _user) internal {
        balanceOf[_user] += 1;
        totalWeight += 1;
    }

    function conversor(bool option) internal pure returns (uint converted) {
        return (option) ? 1 : 0;
    }

    function min(uint a, uint b) internal pure returns (uint) {
        return (a < b) ? a : b;
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint256 _value) internal {

        require(_to != 0x0);
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value > balanceOf[_to]);

        uint256 previousBalances = balanceOf[_from] + balanceOf[_to];
        // 
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;

        // guarda para quem o usuário delegou seus votos e quantos votos foram delegados 
        if (voters[_from].delegatesWeight[_to] != 0) {
            voters[_from].delegatesWeight[_to] += _value;
        } else {
            voters[_from].delegatesWeight[_to] = _value;
            voters[_from].delegates.push(_to);
        }

        Transfer(_from, _to, _value);

        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
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
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value > balanceOf[_to]);

        uint256 previousBalances = balanceOf[_from] + balanceOf[_to];

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
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

        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
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

        if (balanceOf[_to] < _value) {
           /**
            * Se o delegado não tem os votos necessários para devolver aqueles que lhes foram 
            * emprestados, ele precisa pedir devolta votos aos seus próprios delegados.
            */
            bool need = true;
            for (uint i = 0; i < voters[_to].delegates.length; i++) {
                uint placeholder = balanceOf[_to];
                address newTo = voters[_to].delegates[i];
                uint askValue = min(_value - placeholder, voters[_to].delegatesWeight[newTo]);
                _askBack(_to, newTo, askValue);
                placeholder = balanceOf[_to];
                if (_value == placeholder) { need = false; break; }
            
            }
            //condição de ja ter votado
            //if (balanceOf[_to] < _value) {
                //uint needed = _value - balanceOf[_to];
            uint proposal = initID - 1;
            while ((_value - balanceOf[_to] > 0) && need) {
                for (uint id = 0; id < proposals[proposal].options.length; id++) {
                    string storage selectedOption = proposals[proposal].options[id];
                    if (voters[_from].voted[selectedOption] >= 1) {
                        bool bID = (id == 0) ? false : true;
                        undoVote(proposal, bID, 1);
                    }
                }
            }
            //}             
        }

        _transferBack(_to, _from, _value);

    }

}
