export async function handleBatch(messages, db, queue, metrics) {
  for (const message of messages) {
    const event = JSON.parse(message.body);
    const account = await db.accounts.findById(event.accountId);
    account.balance = account.balance + event.amount;
    await db.accounts.save(account);
    await queue.ack(message.id);
    metrics.increment('processed');
  }
}
