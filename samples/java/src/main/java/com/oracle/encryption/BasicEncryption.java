package com.oracle.encryption;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * Demonstrates basic AES-GCM symmetric encryption and decryption using Java's
 * built-in javax.crypto package. AES-GCM provides both confidentiality and
 * integrity protection.
 */
public class BasicEncryption {

    private static final String ALGORITHM = "AES";
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int GCM_IV_LENGTH = 12;  // 96 bits
    private static final int GCM_TAG_LENGTH = 128; // 128 bits

    private final SecretKey secretKey;
    private final SecureRandom secureRandom;

    /**
     * Creates a new BasicEncryption instance with a randomly generated key.
     */
    public BasicEncryption() throws NoSuchAlgorithmException {
        this.secretKey = generateKey();
        this.secureRandom = new SecureRandom();
    }

    /**
     * Creates a new BasicEncryption instance with the provided key.
     *
     * @param key The base64-encoded secret key
     * @throws IllegalArgumentException if the key is invalid
     */
    public BasicEncryption(String key) {
        byte[] decodedKey = Base64.getDecoder().decode(key);
        this.secretKey = new SecretKeySpec(decodedKey, ALGORITHM);
        this.secureRandom = new SecureRandom();
    }

    /**
     * Generates a new 256-bit AES key.
     *
     * @return A new SecretKey
     * @throws NoSuchAlgorithmException if AES key generator is not available
     */
    public SecretKey generateKey() throws NoSuchAlgorithmException {
        KeyGenerator keyGenerator = KeyGenerator.getInstance(ALGORITHM);
        keyGenerator.init(256, secureRandom);
        return keyGenerator.generateKey();
    }

    /**
     * Encrypts plaintext using AES-GCM.
     *
     * @param plaintext The string to encrypt
     * @return Base64-encoded string containing IV and ciphertext (IV:ciphertext)
     */
    public String encrypt(String plaintext) {
        try {
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);

            // Generate a random IV for each encryption
            byte[] iv = new byte[GCM_IV_LENGTH];
            secureRandom.nextBytes(iv);
            GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, parameterSpec);

            byte[] ciphertext = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));

            // Prepend IV to ciphertext for storage
            byte[] ivAndCiphertext = new byte[iv.length + ciphertext.length];
            System.arraycopy(iv, 0, ivAndCiphertext, 0, iv.length);
            System.arraycopy(ciphertext, 0, ivAndCiphertext, iv.length, ciphertext.length);

            return Base64.getEncoder().encodeToString(ivAndCiphertext);
        } catch (Exception e) {
            throw new RuntimeException("Encryption failed", e);
        }
    }

    /**
     * Decrypts ciphertext using AES-GCM.
     *
     * @param ciphertext Base64-encoded string containing IV and ciphertext
     * @return The decrypted plaintext string
     */
    public String decrypt(String ciphertext) {
        try {
            byte[] ivAndCiphertext = Base64.getDecoder().decode(ciphertext);

            // Extract IV and ciphertext
            byte[] iv = new byte[GCM_IV_LENGTH];
            byte[] ciphertextBytes = new byte[ivAndCiphertext.length - GCM_IV_LENGTH];
            System.arraycopy(ivAndCiphertext, 0, iv, 0, GCM_IV_LENGTH);
            System.arraycopy(ivAndCiphertext, GCM_IV_LENGTH, ciphertextBytes, 0, ciphertextBytes.length);

            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
            cipher.init(Cipher.DECRYPT_MODE, secretKey, parameterSpec);

            byte[] plaintext = cipher.doFinal(ciphertextBytes);
            return new String(plaintext, StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new RuntimeException("Decryption failed", e);
        }
    }

    /**
     * Returns the base64-encoded secret key.
     *
     * @return Base64-encoded key string
     */
    public String getKey() {
        return Base64.getEncoder().encodeToString(secretKey.getEncoded());
    }

    /**
     * Demonstrates basic encryption and decryption.
     */
    public static void main(String[] args) {
        System.out.println("=".repeat(60));
        System.out.println("Basic Encryption Demo (AES-GCM)");
        System.out.println("=".repeat(60));

        try {
            // Create encryption instance
            BasicEncryption encryptor = new BasicEncryption();
            System.out.println("\nGenerated Key: " + encryptor.getKey());

            // Encrypt data
            String plaintext = "Sensitive customer data: SSN=123-45-6789";
            String encrypted = encryptor.encrypt(plaintext);
            System.out.println("\nOriginal:  " + plaintext);
            System.out.println("Encrypted: " + encrypted);

            // Decrypt data
            BasicEncryption decryptor = new BasicEncryption(encryptor.getKey());
            String decrypted = decryptor.decrypt(encrypted);
            System.out.println("Decrypted: " + decrypted);

            System.out.println("\n" + "=".repeat(60));
            System.out.println("Demo completed successfully!");
            System.out.println("=".repeat(60));

        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
