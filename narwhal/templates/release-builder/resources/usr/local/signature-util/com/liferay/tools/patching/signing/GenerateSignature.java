package com.liferay.tools.patching.signing;

import java.io.BufferedInputStream;
import java.io.FileInputStream;
import java.math.BigInteger;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.Signature;

public class GenerateSignature {

	public static void main(String[] arguments) {
		if (arguments.length < 5) {
			System.err.println("Required parameters: keystore-file keystore-password key-alias key-password file-to-sign");

			System.exit(1);
		}

		try {
			KeyStore keyStore = KeyStore.getInstance("PKCS12");
			FileInputStream keyStoreFis = new FileInputStream(arguments[0]);
			keyStore.load(keyStoreFis, arguments[1].toCharArray());

			System.out.println(arguments[3]);
			PrivateKey privateKey = (PrivateKey) keyStore.getKey(
				arguments[2], arguments[3].toCharArray());

			Signature signature = Signature.getInstance("SHA256withRSA");

			signature.initSign(privateKey);

			FileInputStream fis = new FileInputStream(arguments[4]);
			BufferedInputStream bufin = new BufferedInputStream(fis);

			byte[] buffer = new byte[1024];
			int len;

			while ((len = bufin.read(buffer)) >= 0) {
				signature.update(buffer, 0, len);
			}

			bufin.close();

			byte[] realSig = signature.sign();

			System.out.println(_toHex(realSig));
		}
		catch (Exception e) {
			e.printStackTrace();

			System.exit(1);
		}
	}

	private static String _toHex(byte[] bytes) {
		BigInteger bi = new BigInteger(1, bytes);
		return String.format("%0" + (bytes.length << 1) + "X", bi);
	}
}
