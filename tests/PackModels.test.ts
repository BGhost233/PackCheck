import { describe, it, expect } from 'vitest';
import { makeId, normalizeNumber, CATEGORY_ALL, CATEGORY_FALLBACK, DEFAULT_CATEGORIES } from '../entry/src/main/ets/models/PackModels.ets';

describe('PackModels - makeId', () => {
  it('generates unique IDs', () => {
    const ids = new Set<string>();
    for (let i = 0; i < 1000; i++) {
      ids.add(makeId('test'));
    }
    expect(ids.size).toBe(1000);
  });

  it('includes prefix', () => {
    const id = makeId('gear');
    expect(id.startsWith('gear_')).toBe(true);
  });

  it('includes timestamp component', () => {
    const before = Date.now();
    const id = makeId('x');
    const after = Date.now();
    // Extract timestamp between first and second underscore
    const parts = id.split('_');
    const ts = Number(parts[1]);
    expect(ts).toBeGreaterThanOrEqual(before);
    expect(ts).toBeLessThanOrEqual(after);
  });
});

describe('PackModels - normalizeNumber', () => {
  it('returns undefined for empty string', () => {
    expect(normalizeNumber('')).toBeUndefined();
    expect(normalizeNumber('   ')).toBeUndefined();
  });

  it('parses integer', () => {
    expect(normalizeNumber('42')).toBe(42);
    expect(normalizeNumber(' 100 ')).toBe(100);
  });

  it('parses float', () => {
    expect(normalizeNumber('3.14')).toBe(3.14);
    expect(normalizeNumber('0.5')).toBe(0.5);
  });

  it('returns undefined for non-numeric', () => {
    expect(normalizeNumber('abc')).toBeUndefined();
    expect(normalizeNumber('12abc')).toBeUndefined();
  });

  it('parses zero', () => {
    expect(normalizeNumber('0')).toBe(0);
  });

  it('parses negative numbers', () => {
    expect(normalizeNumber('-5')).toBe(-5);
    expect(normalizeNumber('-3.2')).toBe(-3.2);
  });
});

describe('PackModels - Constants', () => {
  it('CATEGORY_ALL is "全部"', () => {
    expect(CATEGORY_ALL).toBe('全部');
  });

  it('CATEGORY_FALLBACK is "其他"', () => {
    expect(CATEGORY_FALLBACK).toBe('其他');
  });

  it('DEFAULT_CATEGORIES contains expected items', () => {
    expect(DEFAULT_CATEGORIES).toContain('证件');
    expect(DEFAULT_CATEGORIES).toContain('背负系统');
    expect(DEFAULT_CATEGORIES).toContain('其他');
    expect(DEFAULT_CATEGORIES.length).toBeGreaterThan(5);
  });

  it('DEFAULT_CATEGORIES ends with "其他"', () => {
    expect(DEFAULT_CATEGORIES[DEFAULT_CATEGORIES.length - 1]).toBe('其他');
  });
});
