console.log("To exit, hold down [Ctrl] and press [C] twice.");

//////////
console.log("Test Redis");

const Redis = require('ioredis');
const redis = new Redis();

const main = async () => {

  const arr = ['key', 'value']
  await redis.set(arr);
  
  const result = await redis.get('key');
  console.log(result); /// value

  redis.disconnect();
}

main();
