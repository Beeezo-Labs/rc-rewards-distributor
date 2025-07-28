import { ethers, upgrades } from 'hardhat';
import { expect } from 'chai';
import { Contract, ContractFactory } from 'ethers';
import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';
import { TransactionReceipt, TransactionResponse } from '@ethersproject/abstract-provider';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { BigNumberish, BytesLike } from 'ethers';
import { time } from '@nomicfoundation/hardhat-network-helpers';

describe("Contract 'RewardDistributor'", async () => {
  const PAUSER_ROLE_HASH = '0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a';
  const UPGRADER_ROLE_HASH = '0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3';
  const ADMIN_ROLE_HASH = '0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775';
  const DEFAULT_ADMIN_ROLE_HASH = '0x0000000000000000000000000000000000000000000000000000000000000000';

  const REVERT_ERROR_INVALID_INITIALIZATION = 'InvalidInitialization';
  const REVERT_ERROR_ACCESS_CONTROL_UNAUTHORIZED = 'AccessControlUnauthorizedAccount';
  const REVERT_ERROR_ENFORCED_PAUSE = 'EnforcedPause';
  const REVERT_ERROR_EXPECTED_PAUSE = 'ExpectedPause';
  const REVERT_ERROR_INVALID_AMOUNT = 'InvalidAmount';
  const EVENT_NAME_WITHDRAW_BUDGET = 'WithdrawBudget';
  const REVERT_ERROR_SIGNATURE_REUSE = 'SignatureReuse';
  const REVERT_ERROR_INVALID_SIGNATURE = 'InvalidSignature';
  const REVERT_ERROR_ZERO_AMOUNT = 'ZeroAmount';
  const REVERT_ERROR_SIGNATURE_EXPIRED = 'SignatureExpired';
  const REVERT_ERROR_ZERO_ADDRESS = 'ZeroAddress';

  const EVENT_NAME_DEPOSIT = 'Deposit';
  const EVENT_NAME_SWAP = 'Swap';
  const EVENT_NAME_CLAIM = 'Claim';
  const EVENT_NAME_NEW_ADMIN = 'NewAdmin';
  const EVENT_NAME_NEW_MINIMAL_DEPOSIT = 'NewMinimalDepositAmount';

  const REWARD_COINS_PER_USD = 1000;
  const MINIMAL_DEPOSIT = 1_000_000; // 1 USDC
  const DEPOSIT_AMOUNT = 100_000_000; // 100 USDC
  const DEPOSIT_AMOUNT_USD = 100;
  const REWARDS_AMOUNT = DEPOSIT_AMOUNT_USD * REWARD_COINS_PER_USD;

  let rewardCoinFactory: ContractFactory;
  let stableCoinFactory: ContractFactory;
  let distributorFactory: ContractFactory;

  let rewardCoin: Contract;
  let stableCoin: Contract;

  let deployer: HardhatEthersSigner;
  let pauser: HardhatEthersSigner;
  let admin: HardhatEthersSigner;
  let beeezoVerifier: HardhatEthersSigner;
  let upgrader: HardhatEthersSigner;
  let user: HardhatEthersSigner;

  let rewardCoinAddress: string;
  let stableCoinAddress: string;

  before(async () => {
    [deployer, pauser, admin, beeezoVerifier, upgrader, user] = await ethers.getSigners();
    rewardCoinFactory = await ethers.getContractFactory('RewardCoinMock');
    stableCoinFactory = await ethers.getContractFactory('StableCoinMock');
    distributorFactory = await ethers.getContractFactory('RewardDistributor');

    rewardCoin = (await rewardCoinFactory.deploy()) as Contract;
    await rewardCoin.waitForDeployment;
    rewardCoin = (await rewardCoin.connect(deployer)) as Contract;
    rewardCoinAddress = await rewardCoin.getAddress();

    stableCoin = (await stableCoinFactory.deploy()) as Contract;
    await stableCoin.waitForDeployment;
    stableCoin = (await stableCoin.connect(deployer)) as Contract;
    stableCoinAddress = await stableCoin.getAddress();
  });

  async function deployDistributor(): Promise<{ distributor: Contract }> {
    let distributor: Contract = (await upgrades.deployProxy(distributorFactory, [
      beeezoVerifier.address,
      pauser.address,
      upgrader.address,
      stableCoinAddress,
      rewardCoinAddress,
      MINIMAL_DEPOSIT,
    ])) as Contract;
    await distributor.waitForDeployment;
    distributor = distributor.connect(deployer) as Contract;

    return {
      distributor,
    };
  }

  async function getTx(txResponsePromise: Promise<TransactionResponse>): Promise<TransactionReceipt> {
    const txReceipt = await txResponsePromise;
    return txReceipt.wait();
  }

  async function generateClaimSignature(
    adminSigner: HardhatEthersSigner,
    sender: string,
    distributor: string,
    amount: BigNumberish,
    chainId: number,
    salt: BytesLike,
    deadline: BigNumberish
  ): Promise<string> {
    const domain = {
      name: 'RewardDistributor',
      version: '1.0.0',
      chainId: chainId,
      verifyingContract: distributor,
    };

    const types = {
      ClaimMessage: [
        { name: 'admin', type: 'address' },
        { name: 'sender', type: 'address' },
        { name: 'distributor', type: 'address' },
        { name: 'amount', type: 'uint256' },
        { name: 'chainId', type: 'uint256' },
        { name: 'salt', type: 'bytes32' },
        { name: 'deadline', type: 'uint256' },
      ],
    };

    const value = {
      admin: await adminSigner.getAddress(),
      sender: sender,
      distributor: distributor,
      amount: amount,
      chainId: chainId,
      salt: salt,
      deadline: deadline,
    };

    return await adminSigner.signTypedData(domain, types, value);
  }

  async function generateWithdrawBudgetSignature(
    adminSigner: HardhatEthersSigner,
    sender: string,
    receiver: string,
    distributor: string,
    amount: BigNumberish,
    stableCoin: string,
    chainId: number,
    salt: BytesLike
  ): Promise<string> {
    const domain = {
      name: 'RewardDistributor',
      version: '1.0.0',
      chainId: chainId,
      verifyingContract: distributor,
    };

    const types = {
      WithdrawBudgetMessage: [
        { name: 'admin', type: 'address' },
        { name: 'sender', type: 'address' },
        { name: 'receiver', type: 'address' },
        { name: 'distributor', type: 'address' },
        { name: 'amount', type: 'uint256' },
        { name: 'stableCoin', type: 'address' },
        { name: 'chainId', type: 'uint256' },
        { name: 'salt', type: 'bytes32' },
      ],
    };

    const value = {
      admin: await adminSigner.getAddress(),
      sender: sender,
      receiver: receiver,
      distributor: distributor,
      amount: amount,
      stableCoin: stableCoin,
      chainId: chainId,
      salt: salt,
    };

    return await adminSigner.signTypedData(domain, types, value);
  }

  describe("Functions 'initialize()' adn '_authorizeUpgrade()'", async () => {
    it('Initializer configures contract as expected', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      expect(await distributor.stableCoin()).to.eq(stableCoinAddress);
      expect(await distributor.rewardCoin()).to.eq(rewardCoinAddress);
      expect(await distributor.admin()).to.eq(beeezoVerifier);
      expect(await distributor.minimalDeposit()).to.eq(MINIMAL_DEPOSIT);

      expect(await distributor.hasRole(PAUSER_ROLE_HASH, pauser)).to.eq(true);
      expect(await distributor.hasRole(UPGRADER_ROLE_HASH, upgrader)).to.eq(true);
      expect(await distributor.hasRole(DEFAULT_ADMIN_ROLE_HASH, deployer)).to.eq(true);
      expect(await distributor.hasRole(ADMIN_ROLE_HASH, beeezoVerifier)).to.eq(true);
    });

    it('Initializer is reverted if called second time', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      await expect(
        distributor.initialize(
          beeezoVerifier.address,
          pauser.address,
          upgrader.address,
          stableCoinAddress,
          rewardCoinAddress,
          0
        )
      ).to.be.revertedWithCustomError(distributor, REVERT_ERROR_INVALID_INITIALIZATION);
    });

    it("'upgradeToAndCall()' executes as expected", async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToUpgrader = distributor.connect(upgrader) as Contract;

      const contractAddress = await distributor.getAddress();
      const oldImplementationAddress = await upgrades.erc1967.getImplementationAddress(contractAddress);
      const newImplementation = await distributorFactory.deploy();
      await newImplementation.waitForDeployment();
      const expectedNewImplementationAddress = await newImplementation.getAddress();

      await getTx(distributorConnectedToUpgrader.upgradeToAndCall(expectedNewImplementationAddress, '0x'));

      const actualNewImplementationAddress = await upgrades.erc1967.getImplementationAddress(contractAddress);
      expect(actualNewImplementationAddress).to.eq(expectedNewImplementationAddress);
      expect(actualNewImplementationAddress).not.to.eq(oldImplementationAddress);
    });

    it("'upgradeToAndCall()' is reverted if the caller is not the owner", async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const registryConnectedToAttacker = distributor.connect(user) as Contract;

      await expect(registryConnectedToAttacker.upgradeToAndCall(user.address, '0x'))
        .to.be.revertedWithCustomError(distributor, REVERT_ERROR_ACCESS_CONTROL_UNAUTHORIZED)
        .withArgs(user.address, UPGRADER_ROLE_HASH);
    });
  });

  describe("Function 'pause()'", async () => {
    it('Executes as expected and pauses the contract', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToPauser = distributor.connect(pauser) as Contract;

      expect(await distributorConnectedToPauser.paused()).to.eq(false);
      await distributorConnectedToPauser.pause();
      expect(await distributorConnectedToPauser.paused()).to.eq(true);
    });

    it('Is reverted if the caller does not have pauser role', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToAttacker = distributor.connect(user) as Contract;

      expect(distributorConnectedToAttacker.pause())
        .to.be.revertedWithCustomError(distributor, REVERT_ERROR_ACCESS_CONTROL_UNAUTHORIZED)
        .withArgs(user.address, PAUSER_ROLE_HASH);
    });

    it('Is reverted if the contract is already paused', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToPauser = distributor.connect(pauser) as Contract;
      await distributorConnectedToPauser.pause();
      expect(await distributorConnectedToPauser.paused()).to.eq(true);

      await expect(distributorConnectedToPauser.pause()).to.be.revertedWithCustomError(
        distributor,
        REVERT_ERROR_ENFORCED_PAUSE
      );
    });
  });

  describe("Function 'unpause()'", async () => {
    it('Executes as expected and unpauses the contract', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToPauser = distributor.connect(pauser) as Contract;
      await distributorConnectedToPauser.pause();

      expect(await distributorConnectedToPauser.paused()).to.eq(true);
      await distributorConnectedToPauser.unpause();
      expect(await distributorConnectedToPauser.paused()).to.eq(false);
    });

    it('Is reverted if the caller does not have pauser role', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToAttacker = distributor.connect(user) as Contract;

      expect(distributorConnectedToAttacker.unpause())
        .to.be.revertedWithCustomError(distributor, REVERT_ERROR_ACCESS_CONTROL_UNAUTHORIZED)
        .withArgs(user.address, PAUSER_ROLE_HASH);
    });

    it('Is reverted if the contract is already paused', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToPauser = distributor.connect(pauser) as Contract;
      await distributorConnectedToPauser.pause();
      expect(await distributorConnectedToPauser.paused()).to.eq(true);
      await distributorConnectedToPauser.unpause();

      await expect(distributorConnectedToPauser.unpause()).to.be.revertedWithCustomError(
        distributor,
        REVERT_ERROR_EXPECTED_PAUSE
      );
    });
  });

  describe("Function 'deposit()'", async () => {
    it('Executes as expected and emits the correct event', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      await stableCoin.mint(user, DEPOSIT_AMOUNT);
      await (stableCoin.connect(user) as Contract).approve(await distributor.getAddress(), DEPOSIT_AMOUNT);

      const distributorConnectedToUser = distributor.connect(user) as Contract;
      const tx = await distributorConnectedToUser.deposit(DEPOSIT_AMOUNT);

      expect(tx)
        .to.emit(distributor, EVENT_NAME_DEPOSIT)
        .withArgs(user.address, DEPOSIT_AMOUNT, DEPOSIT_AMOUNT_USD * REWARD_COINS_PER_USD);

      expect(tx).to.changeTokenBalances(stableCoin, [user, distributor], [-DEPOSIT_AMOUNT, +DEPOSIT_AMOUNT]);

      expect(tx).to.changeTokenBalance(rewardCoin, distributor, +(DEPOSIT_AMOUNT_USD * REWARD_COINS_PER_USD));

      expect(await distributor.totalStableCoinsLocked()).to.eq(DEPOSIT_AMOUNT);
      expect(await distributor.totalRewardsAvailable()).to.eq(DEPOSIT_AMOUNT_USD * REWARD_COINS_PER_USD);
    });

    it('Is reverted if the contract is paused', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToPauser = distributor.connect(pauser) as Contract;
      await distributorConnectedToPauser.pause();

      expect(distributor.deposit(DEPOSIT_AMOUNT)).to.be.revertedWithCustomError(
        distributor,
        REVERT_ERROR_ENFORCED_PAUSE
      );
    });

    it('Is reverted if the amount is less than minimal deposit', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      expect(distributor.deposit(MINIMAL_DEPOSIT - 1)).to.be.revertedWithCustomError(
        distributor,
        REVERT_ERROR_INVALID_AMOUNT
      );
    });
  });

  describe("Function 'withdrawBudget()'", async () => {
    it('Executes as expected and emits the correct event', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      await stableCoin.mint(user, DEPOSIT_AMOUNT);
      await (stableCoin.connect(user) as Contract).approve(await distributor.getAddress(), DEPOSIT_AMOUNT);
      await (distributor.connect(user) as Contract).deposit(DEPOSIT_AMOUNT);

      const distributorAddress = await distributor.getAddress();
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const salt = ethers.keccak256(ethers.toUtf8Bytes('withdrawBudgetSalt'));
      const signature = await generateWithdrawBudgetSignature(
        beeezoVerifier,
        user.address,
        user.address,
        distributorAddress,
        DEPOSIT_AMOUNT,
        stableCoinAddress,
        Number(chainId),
        salt
      );

      const distributorConnectedToUser = distributor.connect(user) as Contract;
      const tx = await distributorConnectedToUser.withdrawBudget(user.address, DEPOSIT_AMOUNT, salt, signature);

      await expect(tx)
        .to.emit(distributor, EVENT_NAME_WITHDRAW_BUDGET)
        .withArgs(user.address, DEPOSIT_AMOUNT, REWARDS_AMOUNT);

      await expect(tx).to.changeTokenBalances(stableCoin, [distributor, user], [-DEPOSIT_AMOUNT, +DEPOSIT_AMOUNT]);

      await expect(tx).to.changeTokenBalance(rewardCoin, distributor, -REWARDS_AMOUNT);
    });

    it('Is reverted if the contract is paused', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      const distributorAddress = await distributor.getAddress();
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const salt = ethers.keccak256(ethers.toUtf8Bytes('withdrawBudgetSalt'));
      const signature = await generateWithdrawBudgetSignature(
        beeezoVerifier,
        user.address,
        user.address,
        distributorAddress,
        DEPOSIT_AMOUNT,
        stableCoinAddress,
        Number(chainId),
        salt
      );

      const distributorConnectedToPauser = distributor.connect(pauser) as Contract;
      await distributorConnectedToPauser.pause();

      const distributorConnectedToUser = distributor.connect(user) as Contract;

      await expect(
        distributorConnectedToUser.withdrawBudget(user.address, DEPOSIT_AMOUNT, salt, signature)
      ).to.be.revertedWithCustomError(distributor, REVERT_ERROR_ENFORCED_PAUSE);
    });

    it('Is reverted if the signature is reused', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      await stableCoin.mint(user, DEPOSIT_AMOUNT * 2);
      await (stableCoin.connect(user) as Contract).approve(await distributor.getAddress(), DEPOSIT_AMOUNT * 2);
      await (distributor.connect(user) as Contract).deposit(DEPOSIT_AMOUNT * 2);

      const distributorAddress = await distributor.getAddress();
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const salt = ethers.keccak256(ethers.toUtf8Bytes('withdrawBudgetSalt'));
      const signature = await generateWithdrawBudgetSignature(
        beeezoVerifier,
        user.address,
        user.address,
        distributorAddress,
        DEPOSIT_AMOUNT,
        stableCoinAddress,
        Number(chainId),
        salt
      );

      const distributorConnectedToUser = distributor.connect(user) as Contract;
      await distributorConnectedToUser.withdrawBudget(user.address, DEPOSIT_AMOUNT, salt, signature);

      await expect(
        distributorConnectedToUser.withdrawBudget(user.address, DEPOSIT_AMOUNT, salt, signature)
      ).to.be.revertedWithCustomError(distributor, REVERT_ERROR_SIGNATURE_REUSE);
    });

    it('Is reverted if the signature is invalid', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      const distributorAddress = await distributor.getAddress();
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const salt = ethers.keccak256(ethers.toUtf8Bytes('withdrawBudgetSalt'));
      const invalidSignature = await generateWithdrawBudgetSignature(
        deployer,
        user.address,
        user.address,
        distributorAddress,
        DEPOSIT_AMOUNT,
        stableCoinAddress,
        Number(chainId),
        salt
      );

      const distributorConnectedToUser = distributor.connect(user) as Contract;

      await expect(
        distributorConnectedToUser.withdrawBudget(user.address, DEPOSIT_AMOUNT, salt, invalidSignature)
      ).to.be.revertedWithCustomError(distributor, REVERT_ERROR_INVALID_SIGNATURE);
    });
  });

  describe("Function 'Swap()'", async () => {
    it('Executes as expected and emits the correct event', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      await stableCoin.mint(deployer, DEPOSIT_AMOUNT);
      await stableCoin.approve(await distributor.getAddress(), DEPOSIT_AMOUNT);
      await distributor.deposit(DEPOSIT_AMOUNT);

      const distributorAddress = await distributor.getAddress();
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const salt = ethers.keccak256(ethers.toUtf8Bytes('claimSalt'));
      const deadline = (await time.latest()) + 3600;
      const signature = await generateClaimSignature(
        beeezoVerifier,
        user.address,
        distributorAddress,
        REWARDS_AMOUNT,
        Number(chainId),
        salt,
        deadline
      );

      const distributorConnectedToUser = distributor.connect(user) as Contract;
      await distributorConnectedToUser.claim(REWARDS_AMOUNT, salt, deadline, signature);

      const rewardCoinConnectedToUser = rewardCoin.connect(user) as Contract;
      await rewardCoinConnectedToUser.approve(distributorAddress, REWARDS_AMOUNT);

      const tx = await distributorConnectedToUser.swap(DEPOSIT_AMOUNT);

      await expect(tx).to.emit(distributor, EVENT_NAME_SWAP).withArgs(user.address, DEPOSIT_AMOUNT, REWARDS_AMOUNT);

      await expect(tx).to.changeTokenBalances(stableCoin, [distributor, user], [-DEPOSIT_AMOUNT, +DEPOSIT_AMOUNT]);

      await expect(tx).to.changeTokenBalances(rewardCoin, [user, distributor], [-REWARDS_AMOUNT, 0]);
    });

    it('Is reverted if the contract is paused', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      await stableCoin.mint(deployer, DEPOSIT_AMOUNT);
      await stableCoin.approve(await distributor.getAddress(), DEPOSIT_AMOUNT);
      await distributor.deposit(DEPOSIT_AMOUNT);

      const distributorAddress = await distributor.getAddress();
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const salt = ethers.keccak256(ethers.toUtf8Bytes('claimSalt'));
      const deadline = (await time.latest()) + 3600;
      const signature = await generateClaimSignature(
        beeezoVerifier,
        user.address,
        distributorAddress,
        REWARDS_AMOUNT,
        Number(chainId),
        salt,
        deadline
      );

      const distributorConnectedToUser = distributor.connect(user) as Contract;
      await distributorConnectedToUser.claim(REWARDS_AMOUNT, salt, deadline, signature);

      const rewardCoinConnectedToUser = rewardCoin.connect(user) as Contract;
      await rewardCoinConnectedToUser.approve(distributorAddress, REWARDS_AMOUNT);

      const distributorConnectedToPauser = distributor.connect(pauser) as Contract;
      await distributorConnectedToPauser.pause();

      await expect(distributorConnectedToUser.swap(DEPOSIT_AMOUNT)).to.be.revertedWithCustomError(
        distributor,
        REVERT_ERROR_ENFORCED_PAUSE
      );
    });

    it('Is reverted if the amount is zero', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      const distributorConnectedToUser = distributor.connect(user) as Contract;

      await expect(distributorConnectedToUser.swap(0)).to.be.revertedWithCustomError(
        distributor,
        REVERT_ERROR_ZERO_AMOUNT
      );
    });
  });

  describe("Function 'claim()'", async () => {
    it('Executes as expected and emits the correct event', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      await stableCoin.mint(deployer, DEPOSIT_AMOUNT);
      await stableCoin.approve(await distributor.getAddress(), DEPOSIT_AMOUNT);
      await distributor.deposit(DEPOSIT_AMOUNT);

      const distributorAddress = await distributor.getAddress();
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const salt = ethers.keccak256(ethers.toUtf8Bytes('claimSalt'));
      const deadline = (await time.latest()) + 3600;
      const signature = await generateClaimSignature(
        beeezoVerifier,
        user.address,
        distributorAddress,
        REWARDS_AMOUNT,
        Number(chainId),
        salt,
        deadline
      );

      const distributorConnectedToUser = distributor.connect(user) as Contract;
      const tx = await distributorConnectedToUser.claim(REWARDS_AMOUNT, salt, deadline, signature);

      await expect(tx)
        .to.emit(distributor, EVENT_NAME_CLAIM)
        .withArgs(user.address, user.address, REWARDS_AMOUNT, salt);

      await expect(tx).to.changeTokenBalances(rewardCoin, [distributor, user], [-REWARDS_AMOUNT, +REWARDS_AMOUNT]);
    });

    it('Is reverted if the contract is paused', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      await stableCoin.mint(deployer, DEPOSIT_AMOUNT);
      await stableCoin.approve(await distributor.getAddress(), DEPOSIT_AMOUNT);
      await distributor.deposit(DEPOSIT_AMOUNT);

      const distributorAddress = await distributor.getAddress();
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const salt = ethers.keccak256(ethers.toUtf8Bytes('claimSalt'));
      const deadline = (await time.latest()) + 3600;
      const signature = await generateClaimSignature(
        beeezoVerifier,
        user.address,
        distributorAddress,
        REWARDS_AMOUNT,
        Number(chainId),
        salt,
        deadline
      );

      const distributorConnectedToPauser = distributor.connect(pauser) as Contract;
      await distributorConnectedToPauser.pause();

      const distributorConnectedToUser = distributor.connect(user) as Contract;

      await expect(
        distributorConnectedToUser.claim(REWARDS_AMOUNT, salt, deadline, signature)
      ).to.be.revertedWithCustomError(distributor, REVERT_ERROR_ENFORCED_PAUSE);
    });

    it('Is reverted if the amount is zero', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      const distributorAddress = await distributor.getAddress();
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const salt = ethers.keccak256(ethers.toUtf8Bytes('claimSalt'));
      const deadline = (await time.latest()) + 3600;
      const signature = await generateClaimSignature(
        beeezoVerifier,
        user.address,
        distributorAddress,
        0,
        Number(chainId),
        salt,
        deadline
      );

      const distributorConnectedToUser = distributor.connect(user) as Contract;

      await expect(distributorConnectedToUser.claim(0, salt, deadline, signature)).to.be.revertedWithCustomError(
        distributor,
        REVERT_ERROR_ZERO_AMOUNT
      );
    });

    it('Is reverted if the signature is expired', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      await stableCoin.mint(deployer, DEPOSIT_AMOUNT);
      await stableCoin.approve(await distributor.getAddress(), DEPOSIT_AMOUNT);
      await distributor.deposit(DEPOSIT_AMOUNT);

      const distributorAddress = await distributor.getAddress();
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const salt = ethers.keccak256(ethers.toUtf8Bytes('claimSalt'));
      const deadline = (await time.latest()) - 1;
      const signature = await generateClaimSignature(
        beeezoVerifier,
        user.address,
        distributorAddress,
        REWARDS_AMOUNT,
        Number(chainId),
        salt,
        deadline
      );

      const distributorConnectedToUser = distributor.connect(user) as Contract;

      await expect(
        distributorConnectedToUser.claim(REWARDS_AMOUNT, salt, deadline, signature)
      ).to.be.revertedWithCustomError(distributor, REVERT_ERROR_SIGNATURE_EXPIRED);
    });

    it('Is reverted if the signature is reused', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      await stableCoin.mint(deployer, DEPOSIT_AMOUNT * 2);
      await stableCoin.approve(await distributor.getAddress(), DEPOSIT_AMOUNT * 2);
      await distributor.deposit(DEPOSIT_AMOUNT * 2);

      const distributorAddress = await distributor.getAddress();
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const salt = ethers.keccak256(ethers.toUtf8Bytes('claimSalt'));
      const deadline = (await time.latest()) + 3600;
      const signature = await generateClaimSignature(
        beeezoVerifier,
        user.address,
        distributorAddress,
        REWARDS_AMOUNT,
        Number(chainId),
        salt,
        deadline
      );

      const distributorConnectedToUser = distributor.connect(user) as Contract;
      await distributorConnectedToUser.claim(REWARDS_AMOUNT, salt, deadline, signature);

      await expect(
        distributorConnectedToUser.claim(REWARDS_AMOUNT, salt, deadline, signature)
      ).to.be.revertedWithCustomError(distributor, REVERT_ERROR_SIGNATURE_REUSE);
    });

    it('Is reverted if the signature is invalid', async () => {
      const { distributor } = await loadFixture(deployDistributor);

      await stableCoin.mint(deployer, DEPOSIT_AMOUNT);
      await stableCoin.approve(await distributor.getAddress(), DEPOSIT_AMOUNT);
      await distributor.deposit(DEPOSIT_AMOUNT);

      const distributorAddress = await distributor.getAddress();
      const chainId = (await ethers.provider.getNetwork()).chainId;
      const salt = ethers.keccak256(ethers.toUtf8Bytes('claimSalt'));
      const deadline = (await time.latest()) + 3600;
      const invalidSignature = await generateClaimSignature(
        deployer,
        user.address,
        distributorAddress,
        REWARDS_AMOUNT,
        Number(chainId),
        salt,
        deadline
      );

      const distributorConnectedToUser = distributor.connect(user) as Contract;

      await expect(
        distributorConnectedToUser.claim(REWARDS_AMOUNT, salt, deadline, invalidSignature)
      ).to.be.revertedWithCustomError(distributor, REVERT_ERROR_INVALID_SIGNATURE);
    });
  });

  describe("Function 'setAdmin()'", async () => {
    it('Executes as expected and emits the correct event', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToAdmin = distributor.connect(beeezoVerifier) as Contract;

      expect(await distributor.admin()).to.eq(beeezoVerifier.address);

      const tx = await distributorConnectedToAdmin.setAdmin(user.address);

      await expect(tx).to.emit(distributor, EVENT_NAME_NEW_ADMIN).withArgs(user.address);

      expect(await distributor.admin()).to.eq(user.address);
    });

    it('Is reverted if the caller does not have admin role', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToAttacker = distributor.connect(user) as Contract;

      await expect(distributorConnectedToAttacker.setAdmin(user.address))
        .to.be.revertedWithCustomError(distributor, REVERT_ERROR_ACCESS_CONTROL_UNAUTHORIZED)
        .withArgs(user.address, ADMIN_ROLE_HASH);
    });

    it('Is reverted if the new admin is zero address', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToAdmin = distributor.connect(beeezoVerifier) as Contract;

      await expect(distributorConnectedToAdmin.setAdmin(ethers.ZeroAddress)).to.be.revertedWithCustomError(
        distributor,
        REVERT_ERROR_ZERO_ADDRESS
      );
    });
  });

  describe("Function 'setNewMinimalDeposit()'", async () => {
    it('Executes as expected and emits the correct event', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToAdmin = distributor.connect(beeezoVerifier) as Contract;

      expect(await distributor.minimalDeposit()).to.eq(MINIMAL_DEPOSIT);

      const newMinimal = 123456;

      const tx = await distributorConnectedToAdmin.setNewMinimalDeposit(newMinimal);

      await expect(tx).to.emit(distributor, EVENT_NAME_NEW_MINIMAL_DEPOSIT).withArgs(newMinimal);

      expect(await distributor.minimalDeposit()).to.eq(newMinimal);
    });

    it('Is reverted if the caller does not have admin role', async () => {
      const { distributor } = await loadFixture(deployDistributor);
      const distributorConnectedToAttacker = distributor.connect(user) as Contract;

      await expect(distributorConnectedToAttacker.setNewMinimalDeposit(0))
        .to.be.revertedWithCustomError(distributor, REVERT_ERROR_ACCESS_CONTROL_UNAUTHORIZED)
        .withArgs(user.address, ADMIN_ROLE_HASH);
    });
  });
});
