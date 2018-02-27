pragma solidity ^0.4.18;

//ERC 721 compliant.

contract classAction {
    string public constant name = "ClassActionFunder";
    string public constant symbol = "CAF";
    address public administrator;
    address public trustedThirdParty;
    uint public minParticipationAmount;
    uint public deadline;
    uint public dateStarted;
    uint public amountRaised;
    uint decayPercentPerDay = 1;
    uint public dismissPercentToLawyer = 0;
    uint public finalDecayPercent = 0;
    uint public certificationPercentToLawyer = 0;
    uint public totalLawyerPayout = 0;
    address public lawyer;
    uint public lawyerPayoutPercentage = 0;
    mapping(address => uint256) balanceOf;
    mapping(address => uint256) evidenceOf;
    uint public adminPayoutPercent = 1;

    bool public fundingClosed = false;
    bool public dismissDenied = false;
    bool public certificationSuccessful = false;
    uint public dismissPercent;


    event FundTransfer(address backer, uint amount, bool isContribution);
    event DismissReached(address recipient, uint totalAmountEarned);
    event CertificationReached(address recipient, uint totalAmountEarned);
    event Payout(address toPerson, uint toPay, uint currentBalance, uint amountRaised);
    event DebugDeadline(uint dateStarted, uint now, uint deadline, uint finalDecayPercent);
    event DebugPayoutPercent(uint lawyerPayoutPercentage, uint dismissPercentToLawyer, uint lawyerPayout);
    event DebugPayout(uint balance, uint toPay, uint lawyerPayout);

    /**
     * Constructor function
     *
     * Setup the owner
     */
    function classAction(
        uint durationInDays,
        uint fundingMinInWei,
        address oracle,
        uint percentDismiss
    ) public {
        administrator = msg.sender;
        dateStarted = now;
        deadline = now + (durationInDays * 1 days);
        minParticipationAmount = fundingMinInWei;
        trustedThirdParty = oracle;
        dismissPercent = percentDismiss;
    }

    /**
     * Funding function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function contribute (uint evidenceHash) public payable {
        require(!fundingClosed);
        uint amount = msg.value;
        assert(amount >= minParticipationAmount);
        balanceOf[msg.sender] += amount;
        evidenceOf[msg.sender] = evidenceHash;
        amountRaised += amount;
        FundTransfer(msg.sender, amount, true);
    }

    /**
     * Withdraw the funds
     *
     * Checks to see if cert if successful or if full decay has been reached, 
     * and if so, each contributor can withdraw the amount they contributed.
     */
    function safeWithdrawal() public {
        bool deadlineEnded = now >= (deadline + 100*1 days/decayPercentPerDay);
        if (fundingClosed || deadlineEnded) {
            uint amount = balanceOf[msg.sender];
            balanceOf[msg.sender] = 0;
            if (amount > 0) {
                if (msg.sender.send(amount * (100 - lawyerPayoutPercentage) )) {
                    FundTransfer(msg.sender, amount, false);
                } else {
                    balanceOf[msg.sender] = amount;
                }
            }
        }
    }
    
    function sendCash(uint value) public {
        uint toPay = value;
        Payout(msg.sender, toPay, this.balance, amountRaised);
        assert(msg.sender.send(toPay));
    }
    
    function kill() public {
        if(msg.sender == administrator) {
            selfdestruct(administrator);
        }
    }

    /**
     * Sets if motion to Dismiss was denied.
     * Called only by trustedThirdParty.
     * Ends certification. Pays out the lawyers and the contributors.
     */
    function confirmMotionToDismissDenied(address lawyerAddress) public {
        assert(trustedThirdParty == msg.sender);
        lawyer = lawyerAddress;
        finalDecayPercent = 0;
        if (now > deadline) {
            uint daysAfterDeadline = (now - deadline) / 1 days;        
            finalDecayPercent = daysAfterDeadline * decayPercentPerDay;
            if (finalDecayPercent > 100) {
                finalDecayPercent = 100;
            }
        }
        DebugDeadline(dateStarted, now, deadline, finalDecayPercent);
        dismissPercentToLawyer = (100 - finalDecayPercent) * dismissPercent;
        lawyerPayoutPercentage += dismissPercentToLawyer;
        uint lawyerPayout = amountRaised * dismissPercentToLawyer;
        DebugPayoutPercent(lawyerPayoutPercentage, dismissPercentToLawyer, lawyerPayout);
        if (dismissPercentToLawyer > 0) {
            uint toPay = (lawyerPayout / 10000);
            if (this.balance >= toPay) {
                assert(msg.sender.send( (toPay * adminPayoutPercent)/100 ));
                assert(msg.sender.send( (toPay * (100 - adminPayoutPercent))/100 ));
            } else {
                DebugPayout(this.balance, toPay, lawyerPayout);
            }
        }
        totalLawyerPayout += toPay;
        DismissReached(lawyer, toPay);
        dismissDenied = true;
    }

    /**
     * Sets if certification was successful.
     * Called only by trustedThirdParty.
     * Ends certification. Pays out the lawyers and the contributors.
     */
    function confirmCertification(address lawyerAddress) public {
        assert(trustedThirdParty == msg.sender);
        lawyer = lawyerAddress;
        finalDecayPercent = 0;
        if (now > deadline) {
            uint daysAfterDeadline = (now - deadline) / 1 days;        
            finalDecayPercent = daysAfterDeadline * decayPercentPerDay;
            if (finalDecayPercent > 100) {
                finalDecayPercent = 100;
            }
        }
        DebugDeadline(dateStarted, now, deadline, finalDecayPercent);
        if (dismissDenied) {
            certificationPercentToLawyer = (100 - finalDecayPercent) * (100 - dismissPercent);
        } else {
            certificationPercentToLawyer = (100 - finalDecayPercent) * 100;
        }
        lawyerPayoutPercentage += certificationPercentToLawyer;
        uint lawyerPayout = amountRaised * certificationPercentToLawyer;
        DebugPayoutPercent(lawyerPayoutPercentage, certificationPercentToLawyer, lawyerPayout);
        if (certificationPercentToLawyer > 0) {
            uint toPay = (lawyerPayout / 10000);
            if (this.balance >= toPay) {
                assert(msg.sender.send( (toPay * adminPayoutPercent)/100 ));
                assert(msg.sender.send( (toPay * (100 - adminPayoutPercent))/100 ));
            } else {
                DebugPayout(this.balance, toPay, lawyerPayout);
            }
        }
        totalLawyerPayout += lawyerPayout;
        CertificationReached(lawyer, lawyerPayout);
        certificationSuccessful = true;
        fundingClosed = true;
    }
}


contract securitiesClassAction is classAction {
    string public constant securityName = "Solocoin";
    string public constant symbol = "SSC";

    function securitiesClassAction(
        uint durationInDays,
        uint fundingMinInWei,
        address oracle
    ) public {
        administrator = msg.sender;
        deadline = now + durationInDays * 1 days;
        minParticipationAmount = fundingMinInWei;
        trustedThirdParty = oracle;
    }
}

