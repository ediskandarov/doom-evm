// SPDX-License-Identifier: GPL-2.0-only
// Strict validator for the checked-in v0 schema vocabulary, no npm dependency.
import { requireValid } from './wad.ts';
export function validateSchema(value: any, schema: any, path = '$'): void {
  const supported = new Set(['$schema', '$id', 'title', 'description', 'type', 'const', 'enum', 'properties', 'required', 'additionalProperties', 'items', 'minimum', 'maximum', 'minLength', 'maxLength', 'pattern', 'anyOf']);
  for (const key of Object.keys(schema)) requireValid(supported.has(key), `unsupported schema keyword ${key}`);
  if (schema.anyOf) {
    const matches = schema.anyOf.some((branch: any) => { try { validateSchema(value, branch, path); return true; } catch { return false; } });
    requireValid(matches, `${path}: no anyOf branch matches`);
  }
  if ('const' in schema) requireValid(value === schema.const, `${path}: const mismatch`);
  if (schema.enum) requireValid(schema.enum.includes(value), `${path}: enum mismatch`);
  if (schema.type) {
    const valid = schema.type === 'integer' ? Number.isSafeInteger(value) : schema.type === 'array' ? Array.isArray(value) : schema.type === 'object' ? value !== null && typeof value === 'object' && !Array.isArray(value) : typeof value === schema.type;
    requireValid(valid, `${path}: expected ${schema.type}`);
  }
  if (typeof value === 'number') {
    if ('minimum' in schema) requireValid(value >= schema.minimum, `${path}: below minimum`);
    if ('maximum' in schema) requireValid(value <= schema.maximum, `${path}: above maximum`);
  }
  if (typeof value === 'string') {
    if ('minLength' in schema) requireValid(value.length >= schema.minLength, `${path}: too short`);
    if ('maxLength' in schema) requireValid(value.length <= schema.maxLength, `${path}: too long`);
    if (schema.pattern) requireValid(new RegExp(schema.pattern).test(value), `${path}: pattern mismatch`);
  }
  if (Array.isArray(value) && schema.items) value.forEach((item, i) => validateSchema(item, schema.items, `${path}[${i}]`));
  if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
    for (const key of schema.required || []) requireValid(Object.hasOwn(value, key), `${path}: missing ${key}`);
    for (const key of Object.keys(value)) {
      if (schema.properties && key in schema.properties) validateSchema(value[key], schema.properties[key], `${path}.${key}`);
      else requireValid(schema.additionalProperties !== false, `${path}: extra ${key}`);
    }
  }
}
