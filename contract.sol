pragma solidity ^0.4.2;


contract Liquid {

    string public name;
    string public symbol;
    uint256 public totalSupply;
    uint public initID;
    uint256 decimals = 0;

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
    mapping (address => uint256) private balances; 
    mapping (uint => Proposal) private proposals;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
    event AskBack(address indexed from, address indexed to, uint256 value);
    event CreateProposal(string name, string description, string options, uint minutesDuration, uint initID);
    event Vote(address indexed voter, uint proposal, string option, uint value);
    event UndoVote(address indexed voter, uint proposal, string option, uint value);
    event Winner(string proposal, uint nao, uint sim);

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     * @param tokenName Nome do token que representará o peso de um voto
     * @param tokenSymbol Símbolo de 3 caracteres que representará o token
     */
    function Liquid (
        string tokenName, // nome do token/voto
        string tokenSymbol // símbolo do token
    ) public 
    {
        balances[msg.sender] = 0;
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

    /**
     * How many votes a person has
     */
    function balanceOf(address _owner) public constant returns (uint256 balance) {
        return balances[_owner];
    }

    /**
     * Describe Proposal
     *
     * Gives information about a specific proposal 
     *
     * @param propID Proposal ID 
     */
    function describeProposal(uint propID) public view returns (
        string proposalName, string description, uint minutesRemaining) {
        return (proposals[propID].name, proposals[propID].description, (proposals[propID].activeUntil - now)/60);
    }

    /**
     * Delegated Votes
     * 
     * Show how many votes you delegated to a specific person
     * 
     * @param _to Who you delegated votes to
     */
    function delegatedVotes(address _to) public view returns (uint votes) {
        return (voters[msg.sender].delegatesWeight[_to]);
    }

    /**
     * Proposal Result 
     * 
     * Shows what is the winner proposition and how many votes that proposition had
     *
     * @param propID Proposal ID  
     */
    function proposalResult(uint propID) public {
        require(proposals[propID].exists);
        require(proposals[propID].activeUntil < now);

        Winner(proposals[propID].name, proposals[propID].votes["nao"], proposals[propID].votes["sim"]);
        
    }

    /**
     * Partial Result
     *
     * Shows how many votes each proposition had 
     *
     * @param propID Proposal ID 
     */
    function partialResult(uint propID) public view returns (uint sim, uint nao) {
        return (proposals[propID].votes["sim"], proposals[propID].votes["nao"]);
    }

    /**
     * Vote in a specific proposal 
     * 
     * @param proposal Proposal ID
     * @param agree Do you agree with this proposal?
     * @param value How many votes would you like to give? 
     */
    function vote(uint proposal, bool agree, uint value) public {
        require(balances[msg.sender] >= value);
        require(proposals[proposal].exists);
        require(proposals[proposal].activeUntil >= now);

        string storage selectedOption =  proposals[proposal].options[conversor(agree)];
        uint previousBalances = balances[msg.sender] + proposals[proposal].votes[selectedOption];

        proposals[proposal].votes[selectedOption] += value;
        balances[msg.sender] -= value;
        voters[msg.sender].voted[selectedOption] += value;

        Vote(msg.sender, proposal, selectedOption, value);

        assert(previousBalances == balances[msg.sender] + proposals[proposal].votes[selectedOption]);
    }

    /**
     * Undo a vote in a specific proposal
     *  
     * @param proposal Proposal ID
     * @param option Did you agree with the proposal?
     * @param value How many votes you want to get back
     */
    function undoVote(uint proposal, bool option, uint value) public {
        _undoVote(msg.sender, proposal, option, value);
    }
    
    /**
     * Get Vote tokens.
     *
     * Increments your voting weight by one.
     * 
     */
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
    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

   /**
    * Ask Back
    * 
    * Asks someone whom you delegated your votes to give them back 
    *
    * @param _to Who would you like to ask to give back your votes 
    * @param _value How many votes you'd like to get back  
    */
    function askBack(address _to, uint256 _value) public {
        _askBack(msg.sender, _to, _value);
    }
    
    //==============================================================================
    // start of internal functions. do not write internal functions above this line. 
    //==============================================================================
    /**
     *
     */
    function faucet(address _user) internal {
        balances[_user] += 1;
        totalSupply += 1;
    }

    /**
     *  
     */
    function _undoVote(address from, uint proposal, bool option, uint value) internal {
        require(proposals[proposal].exists);
        string storage selectedOption =  proposals[proposal].options[conversor(option)];
        require(proposals[proposal].votes[selectedOption] >= value);
        require(voters[from].voted[selectedOption] >= value);

        uint previousBalances = balances[from] + proposals[proposal].votes[selectedOption];

        proposals[proposal].votes[selectedOption] -= value;
        voters[from].voted[selectedOption] -= value;
        balances[from] += value;
        string memory _selectedOption = option ? "sim" : "nao";
        UndoVote(from, proposal, _selectedOption, value);
        assert(previousBalances == balances[from] + proposals[proposal].votes[selectedOption]);
    }

    /**
     *  This was not a fun function to write. 
     */
    function conversor(bool option) internal pure returns (uint converted) {
        return (option) ? 1 : 0;
    }

    /**
     *  
     */
    function min(uint a, uint b) internal pure returns (uint) {
        return (a < b) ? a : b;
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint256 _value) internal {

        require(_to != 0x0);
        require(balances[_from] >= _value);
        require(balances[_to] + _value > balances[_to]);

        uint256 previousBalances = balances[_from] + balances[_to];
        // 
        balances[_from] -= _value;
        balances[_to] += _value;

        // guarda para quem o usuário delegou seus votos e quantos votos foram delegados 
        if (voters[_from].delegatesWeight[_to] != 0) {
            voters[_from].delegatesWeight[_to] += _value;
        } else {
            voters[_from].delegatesWeight[_to] = _value;
            voters[_from].delegates.push(_to);
        }

        Transfer(_from, _to, _value);

        assert(balances[_from] + balances[_to] == previousBalances);
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
        require(balances[_from] >= _value);
        require(balances[_to] + _value > balances[_to]);

        uint256 previousBalances = balances[_from] + balances[_to];

        balances[_from] -= _value;
        balances[_to] += _value;
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

        assert(balances[_from] + balances[_to] == previousBalances);
        assert(voters[_to].delegatesWeight[_from] == 0);

    }

    /**
     *  
     */
    function _askBack(address _from, address _to, uint256 _value) internal {
        require(_to != 0x0);
        require(voters[_from].delegatesWeight[_to] != 0);
        require(voters[_from].delegatesWeight[_to] >= _value);

        if (balances[_to] < _value) {
           /**
            * Se o delegado não tem os votos necessários para devolver aqueles que lhes foram 
            * emprestados, ele precisa pedir devolta votos aos seus próprios delegados.
            */
            for (uint i = 0; i < voters[_to].delegates.length; i++) {
                uint placeholder = balances[_to];
                address newTo = voters[_to].delegates[i];
                uint askValue = min(_value - placeholder, voters[_to].delegatesWeight[newTo]);
                _askBack(_to, newTo, askValue);
                placeholder = balances[_to];
                if (_value == placeholder) { break; }
            
            }
            /**
             * Caso o usuário para quem os votos foram delegados tenha utilizado 
             * todos os votos, é necessário desfazer voto(s) dele para que o voto
             * possa ser devolvido ao dono original.
             */
            uint proposal = initID - 1; // TODO: FIX
            while (_value - balances[_to] > 0) {
                for (uint id = 0; id < proposals[proposal].options.length; id++) {
                    string storage selectedOption = proposals[proposal].options[id];
                    if (voters[_to].voted[selectedOption] >= 1) {
                        bool bID = (id == 0) ? false : true;
                        _undoVote(_to, proposal, bID, 1);
                    }
                }
            }          
        }

        _transferBack(_to, _from, _value);

    }

}
