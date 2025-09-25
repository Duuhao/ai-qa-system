package com.ai.qa.user;

import com.ai.qa.user.domain.entity.User;
import com.ai.qa.user.infrastructure.repository.UserRepository;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;
import org.springframework.security.crypto.password.PasswordEncoder;

@Component
public class UserServiceApplicationRunner implements ApplicationRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserServiceApplicationRunner(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(ApplicationArguments args) {
        String defaultUsername = "test123";
        String defaultPassword = "test123";
        if (!userRepository.existsByUsername(defaultUsername)) {
            User user = User.createNewUser(defaultUsername, defaultPassword, "Test User", passwordEncoder);
            userRepository.save(user);
        }
    }
}


