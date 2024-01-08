package com.ecomm.web.mapper;

import com.ecomm.web.dto.user.PaymentDto;
import com.ecomm.web.model.user.Payment;

public class PaymentMapper {
    public static Payment mapToPayment(PaymentDto paymentDto) {
        return Payment.builder()
                        .paymentType(paymentDto.getPaymentType())
                        .provider(paymentDto.getProvider())
                        .accountNo(paymentDto.getAccountNo())
                        .expiry(paymentDto.getExpiry())
                        .build();
    }
    public static PaymentDto mapToPaymentDto(Payment payment) {
        return PaymentDto.builder()
                        .id(payment.getId())
                        .paymentType(payment.getPaymentType())
                        .provider(payment.getProvider())
                        .accountNo(payment.getAccountNo())
                        .expiry(payment.getExpiry())
                        .build();
    }
}
