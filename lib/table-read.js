import { createDecipheriv } from "node:crypto";
import { inflateSync } from "node:zlib";
import { IV, MASK, SLOT, TAG } from "./asset-table.js";
import { mixKey } from "./table-key.js";

/** 解出来的明文；null = 还没解过，"" = 解不开（密文坏了）。 */
let opened = null;

/**
 * 解密槽内容。结果在本进程内只算一次。
 *
 * 调用它的链路是「每次组装 system prompt」——rules.js 的 resolveInjectText 会先算
 * defaultOverrideHash()，而那是 sha256(openSlot())。不缓存的话，每一轮对话都要做
 * 一次 23KB 的 AES-256-GCM 解密 + zlib 解压 + sha256。
 *
 * 缓存安全的前提：SLOT/MASK/TAG/IV 是模块常量，进程活着就不可能变。改它们只有一条路——
 * scripts/embed-default-prompt.mjs 重写 lib/asset-table.js；那个脚本 import 的是
 * table-key.js（sealSlot），不 import 本文件，所以不存在「同进程先写后读拿到旧值」。
 */
export function openSlot() {
  if (opened !== null) return opened;
  try {
    const decipher = createDecipheriv("aes-256-gcm", mixKey(MASK), Buffer.from(IV, "base64"));
    decipher.setAuthTag(Buffer.from(TAG, "base64"));
    const raw = Buffer.concat([
      decipher.update(Buffer.from(SLOT, "base64")),
      decipher.final(),
    ]);
    opened = inflateSync(raw).toString("utf8");
  } catch {
    // 密文/密钥不一致时每次都必失败，缓存 "" 只是省掉重复抛异常。
    opened = "";
  }
  return opened;
}
