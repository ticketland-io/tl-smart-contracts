import {
  Ed25519Keypair,
  JsonRpcProvider,
  RawSigner,
  mainnetConnection,
  TransactionBlock,
} from '@mysten/sui.js'
import {execSync} from 'child_process'
import {
  privateKey,
  supportedCoins,
} from './config.json'

const secretKey = Uint8Array.from(Buffer.from(privateKey, 'hex'))
const keypair = Ed25519Keypair.fromSecretKey(secretKey)
const provider = new JsonRpcProvider(mainnetConnection)
const signer = new RawSigner(keypair, provider)

const publishTicketland = async () => {
  const cliPath = 'sui'
  const packagePath = 'sources/event_registry.move'
  const {modules, dependencies} = JSON.parse(
    execSync(
      `${cliPath} move build --dump-bytecode-as-base64 --path ${packagePath}`,
      {encoding: 'utf-8'},
    ),
  )
  const txb = new TransactionBlock()
  const [upgradeCap] = txb.publish({modules, dependencies})
  txb.transferObjects([upgradeCap], txb.pure(await signer.getAddress()))
  const result = await signer.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    options: {showObjectChanges: true},
  })

  return result
}

const updateConfig = async (packageId, adminCapId, configId) => {
  const txb = new TransactionBlock()

  txb.moveCall({
    target: `${packageId}::event_registry::update_config`,
    arguments: [
      txb.object(adminCapId),
      txb.object(configId),
      txb.pure(supportedCoins),
      txb.pure(100),
      txb.pure(await signer.getAddress()),
      txb.pure([await signer.getAddress()]),
    ],
  })
  const result = await signer.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    options: {showObjectChanges: true},
  })

  console.log('Updated config: ', result.digest)
}

const main = async () => {
  console.log('Deployer: ', await signer.getAddress())

  const result = await publishTicketland()

  const {packageId} = result.objectChanges.find(o => o.type === 'published')
  const adminCapId = result.objectChanges.find(o => o.objectType === `${packageId}::event_registry::AdminCap`).objectId
  const attendanceConfigId = result.objectChanges.find(o => o.objectType === `${packageId}::attendance::Config`).objectId
  const nftRepository = result.objectChanges.find(o => o.objectType === `${packageId}::ticket::NftRepository`).objectId
  const configId = result.objectChanges.find(o => o.objectType === `${packageId}::event_registry::Config`).objectId
  const exchangeRateId = result.objectChanges.find(o => o.objectType === `${packageId}::price_oracle::ExchangeRate`).objectId
  const operatorCapId = result.objectChanges.find(o => o.objectType === `${packageId}::primary_market::OperatorCap`).objectId

  console.log('packageId:', packageId)
  console.log('adminCapId:', adminCapId)
  console.log('operatorCapId:', operatorCapId)
  console.log('attendanceConfigId:', attendanceConfigId)
  console.log('nftRepository:', nftRepository)
  console.log('configId:', configId)
  console.log('exchangeRateId:', exchangeRateId)

  await updateConfig(packageId, adminCapId, configId)
}

main()
