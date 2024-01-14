package com.ecomm.web.service.impl;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.ecomm.web.dto.shopping.OrderItemDto;
import com.ecomm.web.dto.user.AddressDto;
import com.ecomm.web.dto.user.PaymentDto;
import com.ecomm.web.dto.user.Profile;
import com.ecomm.web.dto.user.UserEntityDto;
import com.ecomm.web.model.shopping.OrderDetail;
import com.ecomm.web.model.shopping.OrderItem;
import com.ecomm.web.model.user.Address;
import com.ecomm.web.model.user.Payment;
import com.ecomm.web.model.user.Role;
import com.ecomm.web.model.user.UserEntity;
import com.ecomm.web.repository.AddressRepository;
import com.ecomm.web.repository.OrderDetailRepository;
import com.ecomm.web.repository.OrderItemRepository;
import com.ecomm.web.repository.PaymentRepository;
import com.ecomm.web.repository.RoleRepository;
import com.ecomm.web.repository.UserRepository;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.UserService;

import static com.ecomm.web.mapper.UserEntityMapper.*;
import static com.ecomm.web.mapper.AddressMapper.mapToAddressDto;
import static com.ecomm.web.mapper.OrderItemMapper.mapToOrderItemDto;
import static com.ecomm.web.mapper.AddressMapper.mapToAddress;
import static com.ecomm.web.mapper.PaymentMapper.mapToPayment;
import static com.ecomm.web.mapper.PaymentMapper.mapToPaymentDto;


@Service
public class UserServiceImpl implements UserService {
    @Autowired
    private UserRepository userRepository;
    @Autowired
    private RoleRepository roleRepository;
    @Autowired
    private PasswordEncoder passwordEncoder;
    @Autowired
    private AddressRepository addressRepository;
    @Autowired
    private PaymentRepository paymentRepository;
    @Autowired
    private OrderItemRepository orderItemRepository;
    @Autowired
    private OrderDetailRepository orderDetailRepository;
    @Override
    public void register(UserEntityDto userEntityDto) {     
        UserEntity user = new UserEntity();
        user.setUsername(userEntityDto.getUsername());
        user.setFirstName(userEntityDto.getFirstName());
        user.setLastName(userEntityDto.getLastName());
        user.setTelephone(userEntityDto.getTelephone());
        user.setPassword(passwordEncoder.encode(userEntityDto.getPassword()));
        Role role = roleRepository.findByName("CUSTOMER");
        user.setRoles(Arrays.asList(role));
        userRepository.save(user);               
    }   
    @Override
    public UserEntityDto findByUsername(String username) {
        return mapToUserEntityDto(userRepository.findByUsername(username));
    }
    @Override
    public boolean usernameExists(String username) {
        UserEntity user = userRepository.findByUsername(username);
        if(user == null) return false;
        return true;
    }
    @Override
    public void saveProfile(Profile profile) {
        UserEntity currentUser = userRepository.findByUsername(SecurityUtil.getSessionUser());
        UserEntity user = new UserEntity();
        user.setId(currentUser.getId());
        user.setUsername(profile.getUsername());
        user.setFirstName(profile.getFirstName());
        user.setLastName(profile.getLastName());
        user.setTelephone(profile.getTelephone());
        user.setPassword(passwordEncoder.encode(currentUser.getPassword()));
        Role role = roleRepository.findByName("CUSTOMER");
        user.setRoles(Arrays.asList(role));
        userRepository.save(user);
    }
    @Override
    public List<AddressDto> findAddressByUser(String username) {
        UserEntity user = userRepository.findByUsername(username);
        List<Address> addresses = addressRepository.findByUser(user);
        return addresses.stream().map((address) -> mapToAddressDto(address)).collect(Collectors.toList());
    }
    @Override
    public void saveAddress(AddressDto addressDto) {
        String username = SecurityUtil.getSessionUser();
        UserEntity user = userRepository.findByUsername(username);
        Address address = mapToAddress(addressDto);
        address.setUser(user);
        addressRepository.save(address);
    };
    @Override
    public List<PaymentDto> findPaymentByUser(String username) {
        UserEntity user = userRepository.findByUsername(username);
        List<Payment> payments = paymentRepository.findByUser(user);
        return payments.stream().map((payment) -> mapToPaymentDto(payment)).collect(Collectors.toList());
    }
    @Override
    public void savePayment(PaymentDto paymentDto) {
        Payment payment = mapToPayment(paymentDto);
        String username = SecurityUtil.getSessionUser();
        UserEntity user = userRepository.findByUsername(username);
        payment.setUser(user);
        paymentRepository.save(payment);
    }
    @Override
    public boolean deleteAddressById(Integer addressId) {
        if(addressId != null) {
            Address address = addressRepository.findById(addressId).get();
            List<OrderDetail> orderDetails = orderDetailRepository.findByAddress(address);
            if(orderDetails.isEmpty()) {
                addressRepository.deleteById(addressId);
                return true;
            }
        }
        return false;
    }
    @Override
    public boolean deletePaymentById(Integer paymentId) {
        if(paymentId != null) {
            Payment payment = paymentRepository.findById(paymentId).get();
            List<OrderDetail> orderDetails = orderDetailRepository.findByPayment(payment);
            if(orderDetails.isEmpty()) {
                paymentRepository.deleteById(paymentId);
                return true;
            }
        }
        return false;
    }
    @Override
    public List<OrderItemDto> findPurchasesByUser(String username) {
        UserEntity user = userRepository.findByUsername(username);
        List<OrderItem> orderItems = orderItemRepository.findPurchasesByUser(user.getId());
        return orderItems.stream().map((orderItem) -> mapToOrderItemDto(orderItem)).collect(Collectors.toList());
    }

}
